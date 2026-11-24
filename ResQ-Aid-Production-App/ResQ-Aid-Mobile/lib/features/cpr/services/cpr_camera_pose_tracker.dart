import 'dart:math' as math;
import 'package:camera/camera.dart';

class PoseTrackingFrameResult {
  final double elbowAngleDeg;
  final int? estimatedCompressionBpm;
  final double motionConfidence;

  const PoseTrackingFrameResult({
    required this.elbowAngleDeg,
    this.estimatedCompressionBpm,
    required this.motionConfidence,
  });
}

/// Bộ theo dõi tư thế cánh tay & tần số nhún ép tim CPR trực tiếp từ luồng YUV420 Camera
/// Kết hợp trích xuất trọng tâm không gian 3 dải (Vai - Khuỷu - Cổ tay) và Bộ lọc Kalman 1 chiều.
class CprCameraPoseTracker {
  double _kalmanY = 0.5;
  double _kalmanP = 1.0;
  double _prevFilteredY = 0.5;
  double _prevVelocity = 0.0;
  final List<DateTime> _compressionPeaks = [];

  void reset() {
    _kalmanY = 0.5;
    _kalmanP = 1.0;
    _prevFilteredY = 0.5;
    _prevVelocity = 0.0;
    _compressionPeaks.clear();
  }

  PoseTrackingFrameResult processCameraFrame(CameraImage image) {
    if (image.planes.isEmpty) {
      return const PoseTrackingFrameResult(elbowAngleDeg: 172.0, motionConfidence: 0.0);
    }

    final yPlane = image.planes[0].bytes;
    final w = image.width;
    final h = image.height;
    final rowStride = image.planes[0].bytesPerRow;

    // Trích xuất trọng tâm chuyển động dọc theo 3 tầng: Vai (trên), Khuỷu tay (giữa), Cổ tay (dưới)
    final shoulderPt = _computeBandGradientCentroid(yPlane, w, h, rowStride, 0.12, 0.34);
    final elbowPt = _computeBandGradientCentroid(yPlane, w, h, rowStride, 0.36, 0.62);
    final wristPt = _computeBandGradientCentroid(yPlane, w, h, rowStride, 0.64, 0.88);

    // Tính góc mở hình học tại khớp khuỷu tay từ 2 vector E->S và E->W
    final ux = shoulderPt.x - elbowPt.x;
    final uy = shoulderPt.y - elbowPt.y;
    final vx = wristPt.x - elbowPt.x;
    final vy = wristPt.y - elbowPt.y;

    final normU = math.sqrt(ux * ux + uy * uy) + 1e-6;
    final normV = math.sqrt(vx * vx + vy * vy) + 1e-6;
    final cosTheta = ((ux * vx + uy * vy) / (normU * normV)).clamp(-1.0, 1.0);
    final rawAngleDeg = (math.acos(cosTheta) * 180.0 / math.pi).clamp(130.0, 180.0);

    // Bộ lọc Kalman 1D theo dõi quỹ đạo nhún trục dọc của thân trên để đếm nhịp BPM rảnh tay
    const qProcess = 0.015;
    const rMeasure = 0.08;
    _kalmanP += qProcess;
    final kalmanGain = _kalmanP / (_kalmanP + rMeasure);
    final measuredY = (shoulderPt.y + elbowPt.y) * 0.5;
    _kalmanY = _kalmanY + kalmanGain * (measuredY - _kalmanY);
    _kalmanP = (1.0 - kalmanGain) * _kalmanP;

    final velocity = _kalmanY - _prevFilteredY;
    // Phát hiện điểm cực đại nhấn xuống (velocity đổi dấu từ dương sang âm với biên độ rõ)
    if (_prevVelocity > 0.004 && velocity <= 0.0) {
      final now = DateTime.now();
      if (_compressionPeaks.isEmpty || now.difference(_compressionPeaks.last).inMilliseconds >= 300) {
        _compressionPeaks.add(now);
        if (_compressionPeaks.length > 8) {
          _compressionPeaks.removeAt(0);
        }
      }
    }
    _prevVelocity = velocity;
    _prevFilteredY = _kalmanY;

    int? liveBpm;
    if (_compressionPeaks.length >= 3) {
      int totalMs = 0;
      for (int i = 1; i < _compressionPeaks.length; i++) {
        totalMs += _compressionPeaks[i].difference(_compressionPeaks[i - 1]).inMilliseconds;
      }
      final avgMs = totalMs / (_compressionPeaks.length - 1);
      if (avgMs >= 300 && avgMs <= 1200) {
        liveBpm = (60000.0 / avgMs).round();
      }
    }

    return PoseTrackingFrameResult(
      elbowAngleDeg: shoulderPt.energy > 6.0 ? rawAngleDeg : 174.0,
      estimatedCompressionBpm: liveBpm,
      motionConfidence: (shoulderPt.energy / 35.0).clamp(0.0, 1.0),
    );
  }

  ({double x, double y, double energy}) _computeBandGradientCentroid(
    List<int> yBytes,
    int w,
    int h,
    int stride,
    double yFracStart,
    double yFracEnd,
  ) {
    final yStart = (h * yFracStart).round().clamp(1, h - 2);
    final yEnd = (h * yFracEnd).round().clamp(yStart + 1, h - 1);
    double sumWX = 0.0;
    double sumWY = 0.0;
    double sumW = 0.0;
    int count = 0;

    for (int y = yStart; y < yEnd; y += 4) {
      final rowBase = y * stride;
      for (int x = 4; x < w - 4; x += 4) {
        final idx = rowBase + x;
        if (idx + stride < yBytes.length && idx - 1 >= 0) {
          final gx = (yBytes[idx + 1] - yBytes[idx - 1]).abs();
          final gy = (yBytes[idx + stride] - yBytes[idx]).abs();
          final mag = (gx + gy).toDouble();
          sumWX += (x / w) * mag;
          sumWY += (y / h) * mag;
          sumW += mag;
          count++;
        }
      }
    }

    if (sumW < 1e-3 || count == 0) {
      return (x: 0.5, y: (yFracStart + yFracEnd) * 0.5, energy: 0.0);
    }
    return (x: sumWX / sumW, y: sumWY / sumW, energy: sumW / count);
  }
}
