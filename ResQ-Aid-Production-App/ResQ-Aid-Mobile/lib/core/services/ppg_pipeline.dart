import 'dart:math';

/// Chất lượng tín hiệu quang học PPG
enum PpgQuality {
  unreliable, // Không đáng tin cậy -> Từ chối xuất kết quả (trả về null BPM)
  fair,       // Đạt ngưỡng tối thiểu -> Tham khảo
  good,       // Tín hiệu rõ nét, SQI cao
}

/// Lý do từ chối tín hiệu (SQI Rejection Reason)
enum PpgRejectionReason {
  none,
  tooDark,               // Tín hiệu quá tối (chưa che camera hoặc che sai)
  saturated,             // Cháy sáng bão hòa đèn flash
  lowPerfusion,          // Biên độ AC quá nhỏ so với DC (ép tay quá mạnh hoặc co mạch)
  motionArtifact,        // Rung lắc ngón tay hoặc chuyển động cơ thể
  cprLockout,            // Đang trong chu kỳ ép tim CPR (cấm đo)
  spectralSnrLow,        // Tỷ lệ năng lượng phổ tim quá thấp (< 0.50)
  estimatorMismatch,     // Ước lượng phổ và đỉnh thời gian không khớp
  highCv,                // Nhịp đập không đều (hệ số biến thiên CV > 0.28)
  notEnoughSamples,      // Chưa tích lũy đủ cửa sổ phân tích
}

/// Kết quả đầu ra của một cửa sổ phân tích PPG
class PpgAnalysisResult {
  final int? bpm;                    // null nếu không đạt SQI (tuyệt đối không đoán mò!)
  final PpgQuality quality;
  final PpgRejectionReason reason;
  final double signalQualityIndex;   // Thang điểm 0.0 -> 1.0
  final double filteredSample;       // Giá trị mẫu sau khi lọc Bandpass để vẽ sóng thật
  final double dcLevel;              // Mức sáng nền DC
  final double acAmplitude;          // Biên độ xung AC
  final bool isPulseBeat;            // Đánh dấu thời điểm đỉnh xung tâm thu
  final int detectedBeats;           // Số lượng nhịp đập ghi nhận được trong cửa sổ

  const PpgAnalysisResult({
    this.bpm,
    required this.quality,
    required this.reason,
    required this.signalQualityIndex,
    required this.filteredSample,
    required this.dcLevel,
    required this.acAmplitude,
    this.isPulseBeat = false,
    this.detectedBeats = 0,
  });

  bool get isValid => bpm != null && quality != PpgQuality.unreliable;
}

/// Bộ lọc Biquad IIR bậc 2 (theo RBJ Audio EQ Cookbook)
class BiquadFilter {
  double _b0 = 0, _b1 = 0, _b2 = 0;
  double _a1 = 0, _a2 = 0;
  double _z1 = 0, _z2 = 0;

  void configureLowpass(double f0, double fs, [double q = 0.7071]) {
    final w = 2.0 * pi * f0 / fs;
    final c = cos(w);
    final alpha = sin(w) / (2.0 * q);
    final a0 = 1.0 + alpha;

    _b0 = ((1.0 - c) / 2.0) / a0;
    _b1 = (1.0 - c) / a0;
    _b2 = _b0;
    _a1 = (-2.0 * c) / a0;
    _a2 = (1.0 - alpha) / a0;
  }

  void configureHighpass(double f0, double fs, [double q = 0.7071]) {
    final w = 2.0 * pi * f0 / fs;
    final c = cos(w);
    final alpha = sin(w) / (2.0 * q);
    final a0 = 1.0 + alpha;

    _b0 = ((1.0 + c) / 2.0) / a0;
    _b1 = (-(1.0 + c)) / a0;
    _b2 = _b0;
    _a1 = (-2.0 * c) / a0;
    _a2 = (1.0 - alpha) / a0;
  }

  double process(double x) {
    final y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  void reset() {
    _z1 = 0.0;
    _z2 = 0.0;
  }
}

/// Pipeline xử lý tín hiệu PPG y sinh:
/// 1. VFR Resampling về 30 Hz cố định dùng Stopwatch
/// 2. Bộ lọc thông dải Butterworth nối tầng 0.65 Hz - 3.6 Hz (39 - 216 BPM)
/// 3. Hệ thống cổng SQI (Signal Quality Index) + Tự tương quan chuẩn hóa dưới mẫu (Parabolic Sub-sample)
class PpgPipeline {
  static const double targetSamplingRate = 30.0; // 30 Hz
  static const int samplePeriodMs = 33;          // ~33.33 ms
  static const int windowSeconds = 10;           // Cửa sổ phân tích 10s
  static const int windowSize = 300;             // 300 mẫu tại 30 Hz

  final BiquadFilter _hpf = BiquadFilter();
  final BiquadFilter _lpf = BiquadFilter();

  final Stopwatch _stopwatch = Stopwatch();
  int _lastRawTimestampMs = 0;
  double _lastRawValue = 0.0;
  double _runningDc = 0.0;

  final List<double> _resampledBuffer = [];
  final List<double> _filteredBuffer = [];
  int _nextResampleTargetTimeMs = 0;

  final List<int> _recentValidBpms = [];
  int _consecutiveInvalidFrames = 0;

  bool isCprActive = false;
  bool isMotionDetected = false;
  int totalDetectedPulses = 0;

  int? get lastValidBpm => _recentValidBpms.isNotEmpty
      ? (List<int>.from(_recentValidBpms)..sort())[_recentValidBpms.length ~/ 2]
      : null;

  PpgPipeline() {
    _hpf.configureHighpass(0.6, targetSamplingRate);
    _lpf.configureLowpass(3.8, targetSamplingRate);
    _stopwatch.start();
  }

  void reset() {
    _hpf.reset();
    _lpf.reset();
    _resampledBuffer.clear();
    _filteredBuffer.clear();
    _recentValidBpms.clear();
    _consecutiveInvalidFrames = 0;
    _lastRawTimestampMs = 0;
    _lastRawValue = 0.0;
    _runningDc = 0.0;
    _nextResampleTargetTimeMs = 0;
    totalDetectedPulses = 0;
  }

  PpgAnalysisResult processFrame(double rawValue, [int? timestampMs]) {
    final nowMs = timestampMs ?? _stopwatch.elapsedMilliseconds;

    if (isCprActive) {
      return PpgAnalysisResult(
        bpm: null,
        quality: PpgQuality.unreliable,
        reason: PpgRejectionReason.cprLockout,
        signalQualityIndex: 0.0,
        filteredSample: 0.0,
        dcLevel: rawValue,
        acAmplitude: 0.0,
      );
    }

    if (isMotionDetected) {
      return PpgAnalysisResult(
        bpm: null,
        quality: PpgQuality.unreliable,
        reason: PpgRejectionReason.motionArtifact,
        signalQualityIndex: 0.0,
        filteredSample: 0.0,
        dcLevel: rawValue,
        acAmplitude: 0.0,
      );
    }

    // Chỉ reset khi mất luồng ảnh > 1.2 giây (tránh mất dữ liệu khi TTS/GC khựng nhẹ 250-400ms)
    if (_lastRawTimestampMs > 0 && (nowMs - _lastRawTimestampMs) > 1200) {
      reset();
    }

    if (_lastRawTimestampMs == 0) {
      _lastRawTimestampMs = nowMs;
      _lastRawValue = rawValue;
      _nextResampleTargetTimeMs = nowMs;
      return _makeUnreliableResult(rawValue, PpgRejectionReason.notEnoughSamples);
    }

    double latestFiltered = 0.0;
    while (_nextResampleTargetTimeMs <= nowMs) {
      final t = (nowMs == _lastRawTimestampMs)
          ? 1.0
          : ((_nextResampleTargetTimeMs - _lastRawTimestampMs) / (nowMs - _lastRawTimestampMs)).clamp(0.0, 1.0);
      final interpolatedRaw = _lastRawValue + t * (rawValue - _lastRawValue);

      if (_runningDc == 0.0) {
        _runningDc = interpolatedRaw;
      } else {
        _runningDc += 0.04 * (interpolatedRaw - _runningDc);
      }
      final acInput = interpolatedRaw - _runningDc;

      final afterHpf = _hpf.process(acInput);
      latestFiltered = _lpf.process(afterHpf);

      _resampledBuffer.add(interpolatedRaw);
      _filteredBuffer.add(latestFiltered);

      if (_resampledBuffer.length > windowSize) {
        _resampledBuffer.removeAt(0);
        _filteredBuffer.removeAt(0);
      }

      _nextResampleTargetTimeMs += samplePeriodMs;
    }

    _lastRawTimestampMs = nowMs;
    _lastRawValue = rawValue;

    // Bắt đầu ước lượng sớm từ 50 mẫu (~1.6 giây) để phản hồi số BPM tức thì
    if (_filteredBuffer.length < 50) {
      return _rejectFrame(rawValue, PpgRejectionReason.notEnoughSamples, latestFiltered);
    }

    return _analyzeWindow(latestFiltered);
  }

  PpgAnalysisResult _makeUnreliableResult(
    double dc,
    PpgRejectionReason reason, [
    double filtered = 0.0,
    bool isPulseBeat = false,
    int detectedBeats = 0,
  ]) {
    return PpgAnalysisResult(
      bpm: null,
      quality: PpgQuality.unreliable,
      reason: reason,
      signalQualityIndex: 0.0,
      filteredSample: filtered,
      dcLevel: dc,
      acAmplitude: 0.0,
      isPulseBeat: isPulseBeat,
      detectedBeats: detectedBeats,
    );
  }

  PpgAnalysisResult _rejectFrame(
    double dc,
    PpgRejectionReason reason, [
    double filtered = 0.0,
    bool isPulseBeat = false,
    int detectedBeats = 0,
  ]) {
    _consecutiveInvalidFrames++;
    if (_consecutiveInvalidFrames >= 15) {
      _recentValidBpms.clear();
    }
    return _makeUnreliableResult(dc, reason, filtered, isPulseBeat, detectedBeats);
  }

  PpgAnalysisResult _analyzeWindow(double latestFiltered) {
    final dcAvg = _resampledBuffer.reduce((a, b) => a + b) / _resampledBuffer.length;
    if (dcAvg < 15.0) {
      _recentValidBpms.clear();
      _consecutiveInvalidFrames = 15;
      return _makeUnreliableResult(dcAvg, PpgRejectionReason.tooDark, latestFiltered);
    }
    if (dcAvg > 250.0) {
      _recentValidBpms.clear();
      _consecutiveInvalidFrames = 15;
      return _makeUnreliableResult(dcAvg, PpgRejectionReason.saturated, latestFiltered);
    }

    // Bỏ qua giai đoạn quá độ đầu của bộ lọc IIR nếu đệm đủ dài
    final analysisSig = _filteredBuffer.length > 95
        ? _filteredBuffer.sublist(12)
        : _filteredBuffer;

    double minFiltered = analysisSig.first;
    double maxFiltered = analysisSig.first;
    for (final v in analysisSig) {
      if (v < minFiltered) minFiltered = v;
      if (v > maxFiltered) maxFiltered = v;
    }
    final acAmplitude = maxFiltered - minFiltered;
    final perfusionIndex = acAmplitude / max(1.0, dcAvg);

    if (acAmplitude < 0.08 || perfusionIndex < 0.0005) {
      return _rejectFrame(dcAvg, PpgRejectionReason.lowPerfusion, latestFiltered);
    }

    // ƯỚC LƯỢNG 1: Dò đỉnh sóng miền thời gian
    final peaks = <int>[];
    final threshold = acAmplitude * 0.16;

    for (int i = 1; i < analysisSig.length - 1; i++) {
      if (analysisSig[i] > threshold &&
          analysisSig[i] > analysisSig[i - 1] &&
          analysisSig[i] >= analysisSig[i + 1]) {
        if (peaks.isEmpty || (i - peaks.last) >= 9) {
          peaks.add(i);
        }
      }
    }

    final bool isPulseBeat = peaks.isNotEmpty && (analysisSig.length - 1 - peaks.last) <= 1;
    if (isPulseBeat) {
      totalDetectedPulses++;
    }

    if (peaks.length < 2) {
      return _rejectFrame(
        dcAvg,
        PpgRejectionReason.notEnoughSamples,
        latestFiltered,
        isPulseBeat,
        peaks.length,
      );
    }

    final ibis = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      final ibiSec = (peaks[i] - peaks[i - 1]) / targetSamplingRate;
      if (ibiSec >= 0.30 && ibiSec <= 1.65) {
        ibis.add(ibiSec);
      }
    }

    if (ibis.isEmpty) {
      return _rejectFrame(
        dcAvg,
        PpgRejectionReason.highCv,
        latestFiltered,
        isPulseBeat,
        peaks.length,
      );
    }

    final sortedIbis = List<double>.from(ibis)..sort();
    final medianIbi = sortedIbis[sortedIbis.length ~/ 2];
    final cleanIbis = sortedIbis.length >= 4
        ? sortedIbis.where((v) => (v - medianIbi).abs() <= medianIbi * 0.35).toList()
        : sortedIbis;
    final effectiveIbis = cleanIbis.length >= 2 ? cleanIbis : sortedIbis;

    final meanIbi = effectiveIbis.reduce((a, b) => a + b) / effectiveIbis.length;
    double sumVariance = 0.0;
    for (final v in effectiveIbis) {
      sumVariance += (v - meanIbi) * (v - meanIbi);
    }
    final stdIbi = sqrt(sumVariance / effectiveIbis.length);
    final cv = meanIbi > 0 ? (stdIbi / meanIbi) : 1.0;

    if (effectiveIbis.length >= 2 && cv > 0.28) {
      return _rejectFrame(
        dcAvg,
        PpgRejectionReason.highCv,
        latestFiltered,
        isPulseBeat,
        peaks.length,
      );
    }

    final timeDomainBpm = (60.0 / medianIbi).round();

    // ƯỚC LƯỢNG 2: Tự tương quan chuẩn hóa nội suy Parabol dưới mẫu
    final autocorr = _estimateBpmByAutocorrelation(analysisSig);
    if (autocorr == null || autocorr.normStrength < 0.34) {
      // Cho phép phản hồi sớm trong 3 giây đầu nếu có ít nhất 2 nhịp rất chuẩn (cv <= 0.10)
      if (analysisSig.length < 90 && peaks.length >= 2 && cv <= 0.10 && timeDomainBpm >= 48 && timeDomainBpm <= 160) {
        _consecutiveInvalidFrames = 0;
        _recentValidBpms.add(timeDomainBpm);
        return PpgAnalysisResult(
          bpm: timeDomainBpm,
          quality: PpgQuality.fair,
          reason: PpgRejectionReason.none,
          signalQualityIndex: 0.52,
          filteredSample: latestFiltered,
          dcLevel: dcAvg,
          acAmplitude: acAmplitude,
          isPulseBeat: isPulseBeat,
          detectedBeats: peaks.length,
        );
      }
      return _rejectFrame(
        dcAvg,
        PpgRejectionReason.spectralSnrLow,
        latestFiltered,
        isPulseBeat,
        peaks.length,
      );
    }

    final autocorrBpm = autocorr.bpm;
    final diff = (timeDomainBpm - autocorrBpm).abs();
    final diffPercent = diff / max(1.0, timeDomainBpm.toDouble());

    final isEarlyWindow = analysisSig.length < 120;
    final maxAllowedDiff = isEarlyWindow ? 14 : 10;
    final maxAllowedDiffPercent = isEarlyWindow ? 0.16 : 0.12;

    if (diff > maxAllowedDiff && diffPercent > maxAllowedDiffPercent) {
      return _rejectFrame(
        dcAvg,
        PpgRejectionReason.estimatorMismatch,
        latestFiltered,
        isPulseBeat,
        peaks.length,
      );
    }

    final sqiScore = (0.55 * autocorr.normStrength + 0.45 * (1.0 - cv * 2.0)).clamp(0.0, 1.0);
    if (sqiScore < 0.50) {
      return _rejectFrame(
        dcAvg,
        PpgRejectionReason.spectralSnrLow,
        latestFiltered,
        isPulseBeat,
        peaks.length,
      );
    }

    final rawCombinedBpm = ((timeDomainBpm + autocorrBpm) / 2).round().clamp(38, 210);

    _consecutiveInvalidFrames = 0;
    _recentValidBpms.add(rawCombinedBpm);
    if (_recentValidBpms.length > 7) {
      _recentValidBpms.removeAt(0);
    }
    final smoothSorted = List<int>.from(_recentValidBpms)..sort();
    final finalBpm = smoothSorted[smoothSorted.length ~/ 2];

    final quality = sqiScore >= 0.72 ? PpgQuality.good : PpgQuality.fair;

    return PpgAnalysisResult(
      bpm: finalBpm,
      quality: quality,
      reason: PpgRejectionReason.none,
      signalQualityIndex: sqiScore,
      filteredSample: latestFiltered,
      dcLevel: dcAvg,
      acAmplitude: acAmplitude,
      isPulseBeat: isPulseBeat,
      detectedBeats: peaks.length,
    );
  }

  ({int bpm, double normStrength})? _estimateBpmByAutocorrelation(List<double> signal) {
    if (signal.length < 45) return null;

    double zeroLagEnergy = 0.0;
    for (int i = 0; i < signal.length; i++) {
      zeroLagEnergy += signal[i] * signal[i];
    }
    final meanEnergy = zeroLagEnergy / signal.length;
    if (meanEnergy < 1e-8) return null;

    const minLag = 9;
    const maxLag = 50;
    final upperLag = min(maxLag, max(minLag + 1, signal.length - 15));
    if (upperLag <= minLag) return null;

    final corrs = List<double>.filled(upperLag + 2, 0.0);
    double maxCorr = -double.infinity;
    int bestLag = -1;

    for (int lag = minLag; lag <= upperLag; lag++) {
      double sum = 0.0;
      final count = signal.length - lag;
      for (int i = 0; i < count; i++) {
        sum += signal[i] * signal[i + lag];
      }
      final normCorr = (sum / count) / meanEnergy;
      corrs[lag] = normCorr;
      if (normCorr > maxCorr) {
        maxCorr = normCorr;
        bestLag = lag;
      }
    }

    if (bestLag > 0 && maxCorr > 0) {
      final halfLag = bestLag ~/ 2;
      if (halfLag >= minLag && corrs[halfLag] >= maxCorr * 0.75) {
        bestLag = halfLag;
        maxCorr = corrs[halfLag];
      }

      double refinedLag = bestLag.toDouble();
      if (bestLag > minLag && bestLag < upperLag) {
        final yPrev = corrs[bestLag - 1];
        final yPeak = corrs[bestLag];
        final yNext = corrs[bestLag + 1];
        final denom = (yPrev - 2.0 * yPeak + yNext);
        if (denom.abs() > 1e-6) {
          final delta = 0.5 * (yPrev - yNext) / denom;
          refinedLag = bestLag + delta.clamp(-0.5, 0.5);
        }
      }

      final bpm = (30.0 * 60.0 / refinedLag).round();
      return (bpm: bpm, normStrength: maxCorr.clamp(0.0, 1.0));
    }
    return null;
  }
}
