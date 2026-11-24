package vn.edu.vku.resq_aid

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.BatteryManager
import android.os.Build
import android.speech.SpeechRecognizer
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val channelName = "vn.edu.vku.resq_aid/device_health"
    private val imageDecodeExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "decodeImageToRgb" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val targetSize = call.argument<Int>("targetSize") ?: 48
                        val viewAspect = call.argument<Double>("viewAspect")
                        val roiLeft = call.argument<Double>("roiLeft")
                        val roiTop = call.argument<Double>("roiTop")
                        val roiRight = call.argument<Double>("roiRight")
                        val roiBottom = call.argument<Double>("roiBottom")

                        if (bytes == null || bytes.isEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        // Giải mã trực tiếp bằng C++ libjpeg-turbo / Skia trên CPU RAM (ARGB_8888)
                        // Tránh hoàn toàn lỗi treo vô tận Impeller Vulkan ui.Image.toByteData trên Xiaomi/HyperOS/Android
                        imageDecodeExecutor.execute {
                            try {
                                val rgbBytes = decodeCpuRgbPatch(
                                    bytes = bytes,
                                    targetSize = targetSize,
                                    viewAspect = viewAspect,
                                    roiLeft = roiLeft,
                                    roiTop = roiTop,
                                    roiRight = roiRight,
                                    roiBottom = roiBottom
                                )
                                runOnUiThread { result.success(rgbBytes) }
                            } catch (e: Throwable) {
                                runOnUiThread { result.success(null) }
                            }
                        }
                    }

                    "getBatteryTemperature" -> {
                        try {
                            val intent = context.registerReceiver(
                                null,
                                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                            )
                            val rawTemp = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 360) ?: 360
                            result.success(rawTemp / 10.0)
                        } catch (e: Exception) {
                            result.success(36.0)
                        }
                    }

                    "getMemoryInfo" -> {
                        try {
                            val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val memInfo = ActivityManager.MemoryInfo()
                            actManager.getMemoryInfo(memInfo)
                            val totalMb = (memInfo.totalMem / (1024 * 1024)).toInt()
                            val availMb = (memInfo.availMem / (1024 * 1024)).toInt()
                            val recommendedModel = if (totalMb >= 5500) {
                                "Qwen2.5-1.5B-Instruct-Q4_K_M"
                            } else {
                                "Qwen2.5-0.5B-Instruct-Q4_K_M"
                            }
                            result.success(
                                mapOf(
                                    "totalRamMb" to totalMb,
                                    "availRamMb" to availMb,
                                    "lowMemory" to memInfo.lowMemory,
                                    "cpuCores" to Runtime.getRuntime().availableProcessors(),
                                    "recommendedModel" to recommendedModel
                                )
                            )
                        } catch (e: Exception) {
                            result.success(
                                mapOf(
                                    "totalRamMb" to 4096,
                                    "availRamMb" to 2048,
                                    "lowMemory" to false,
                                    "cpuCores" to 4,
                                    "recommendedModel" to "Qwen2.5-0.5B-Instruct-Q4_K_M"
                                )
                            )
                        }
                    }

                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(true)
                    }

                    "setScreenBrightness" -> {
                        val brightness = call.argument<Double>("brightness") ?: 1.0
                        runOnUiThread {
                            val lp = window.attributes
                            lp.screenBrightness = brightness.toFloat().coerceIn(0.01f, 1.0f)
                            window.attributes = lp
                        }
                        result.success(true)
                    }

                    "resetScreenBrightness" -> {
                        runOnUiThread {
                            val lp = window.attributes
                            lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            window.attributes = lp
                        }
                        result.success(true)
                    }

                    "getSpeechCapabilities" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(context)
                        val onDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
                        } else {
                            false
                        }
                        result.success(
                            mapOf(
                                "recognitionAvailable" to available,
                                "onDeviceRecognitionAvailable" to onDevice,
                                "sdkInt" to Build.VERSION.SDK_INT
                            )
                        )
                    }

                    "getHardwareCameraProbe" -> {
                        try {
                            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                            val idList = cameraManager.cameraIdList.toList()
                            val cameraDetails = mutableListOf<Map<String, Any?>>()
                            
                            for (id in idList) {
                                val charac = cameraManager.getCameraCharacteristics(id)
                                val facing = charac.get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)
                                val physicalIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    charac.physicalCameraIds.toList()
                                } else {
                                    emptyList<String>()
                                }
                                val focalLengths = charac.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.map { it.toDouble() } ?: emptyList()
                                cameraDetails.add(
                                    mapOf(
                                        "id" to id,
                                        "facing" to facing,
                                        "physicalIds" to physicalIds,
                                        "focals" to focalLengths
                                    )
                                )
                            }
                            result.success(
                                mapOf(
                                    "cameraIds" to idList,
                                    "details" to cameraDetails
                                )
                            )
                        } catch (e: Exception) {
                            result.error("CAMERA_PROBE_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun decodeCpuRgbPatch(
        bytes: ByteArray,
        targetSize: Int,
        viewAspect: Double?,
        roiLeft: Double?,
        roiTop: Double?,
        roiRight: Double?,
        roiBottom: Double?
    ): ByteArray? {
        val boundsOpts = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, boundsOpts)
        if (boundsOpts.outWidth <= 0 || boundsOpts.outHeight <= 0) return null

        val minSpan = if (roiLeft != null && roiTop != null && roiRight != null && roiBottom != null) {
            min(roiRight - roiLeft, roiBottom - roiTop).coerceIn(0.12, 1.0)
        } else {
            1.0
        }
        val desiredMinPx = ((targetSize / minSpan) * 1.8).toInt().coerceIn(targetSize, 384)
        val rawMinDim = min(boundsOpts.outWidth, boundsOpts.outHeight)
        var sampleSize = 1
        while (rawMinDim / (sampleSize * 2) >= desiredMinPx) {
            sampleSize *= 2
        }

        val decodeOpts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = false
        }
        var bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, decodeOpts) ?: return null

        // Xoay đúng chiều ảnh camera nếu có cờ EXIF Orientation
        val rotationDeg = readJpegExifRotationDegrees(bytes)
        if (rotationDeg != 0) {
            val matrix = Matrix().apply { postRotate(rotationDeg.toFloat()) }
            val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
            if (rotated !== bmp) {
                bmp.recycle()
                bmp = rotated
            }
        }

        // Căn khớp chính xác vùng hiển thị BoxFit.cover trên màn hình (loại bỏ dải thừa trên/dưới hoặc trái/phải)
        if (viewAspect != null && viewAspect > 0.1 && bmp.width > 4 && bmp.height > 4) {
            val imgAspect = bmp.width.toDouble() / bmp.height.toDouble()
            if (kotlin.math.abs(imgAspect - viewAspect) > 0.03) {
                val (cx, cy, cw, ch) = if (imgAspect > viewAspect) {
                    val visW = (bmp.height * viewAspect).toInt().coerceIn(2, bmp.width)
                    val xOff = ((bmp.width - visW) / 2).coerceAtLeast(0)
                    intArrayOf(xOff, 0, visW, bmp.height)
                } else {
                    val visH = (bmp.width / viewAspect).toInt().coerceIn(2, bmp.height)
                    val yOff = ((bmp.height - visH) / 2).coerceAtLeast(0)
                    intArrayOf(0, yOff, bmp.width, visH)
                }
                val coverBmp = Bitmap.createBitmap(bmp, cx, cy, cw, ch)
                if (coverBmp !== bmp) {
                    bmp.recycle()
                    bmp = coverBmp
                }
            }
        }

        // Cắt vùng khung ngắm ROI nếu người dùng chọn vùng cụ thể
        if (roiLeft != null && roiTop != null && roiRight != null && roiBottom != null) {
            val w = bmp.width
            val h = bmp.height
            val x0 = (roiLeft * w).toInt().coerceIn(0, max(0, w - 1))
            val y0 = (roiTop * h).toInt().coerceIn(0, max(0, h - 1))
            val x1 = (roiRight * w).toInt().coerceIn(x0 + 1, w)
            val y1 = (roiBottom * h).toInt().coerceIn(y0 + 1, h)
            val cropped = Bitmap.createBitmap(bmp, x0, y0, x1 - x0, y1 - y0)
            if (cropped !== bmp) {
                bmp.recycle()
                bmp = cropped
            }
        }

        // Nội suy Bilinear chuẩn về đúng kích thước mạng nơ-ron [48 x 48]
        val scaled = if (bmp.width == targetSize && bmp.height == targetSize) {
            bmp
        } else {
            Bitmap.createScaledBitmap(bmp, targetSize, targetSize, true)
        }
        if (scaled !== bmp) {
            bmp.recycle()
        }

        val pixelCount = targetSize * targetSize
        val argb = IntArray(pixelCount)
        scaled.getPixels(argb, 0, targetSize, 0, 0, targetSize, targetSize)
        scaled.recycle()

        val outRgb = ByteArray(pixelCount * 3)
        var outIdx = 0
        for (i in 0 until pixelCount) {
            val px = argb[i]
            outRgb[outIdx++] = ((px shr 16) and 0xFF).toByte()
            outRgb[outIdx++] = ((px shr 8) and 0xFF).toByte()
            outRgb[outIdx++] = (px and 0xFF).toByte()
        }
        return outRgb
    }

    /// Đọc nhanh cờ hướng ảnh EXIF JPEG (APP1) thuần Kotlin không cần thư viện ngoài
    private fun readJpegExifRotationDegrees(jpeg: ByteArray): Int {
        try {
            if (jpeg.size < 14 || (jpeg[0].toInt() and 0xFF) != 0xFF || (jpeg[1].toInt() and 0xFF) != 0xD8) {
                return 0
            }
            var offset = 2
            while (offset + 4 < jpeg.size) {
                if ((jpeg[offset].toInt() and 0xFF) != 0xFF) return 0
                val marker = jpeg[offset + 1].toInt() and 0xFF
                if (marker == 0xDA || marker == 0xD9) return 0
                val segLen = ((jpeg[offset + 2].toInt() and 0xFF) shl 8) or (jpeg[offset + 3].toInt() and 0xFF)
                if (segLen < 2 || offset + 2 + segLen > jpeg.size) return 0

                if (marker == 0xE1 && segLen >= 14) {
                    val tiffStart = offset + 10
                    if (tiffStart + 8 < jpeg.size &&
                        jpeg[offset + 4] == 'E'.code.toByte() &&
                        jpeg[offset + 5] == 'x'.code.toByte() &&
                        jpeg[offset + 6] == 'i'.code.toByte() &&
                        jpeg[offset + 7] == 'f'.code.toByte()
                    ) {
                        val littleEndian = jpeg[tiffStart] == 'I'.code.toByte() && jpeg[tiffStart + 1] == 'I'.code.toByte()
                        val ifdOffset = readInt32(jpeg, tiffStart + 4, littleEndian)
                        val dirStart = tiffStart + ifdOffset
                        if (dirStart + 2 >= jpeg.size) return 0
                        val entryCount = readUint16(jpeg, dirStart, littleEndian)
                        for (i in 0 until entryCount) {
                            val entryPos = dirStart + 2 + i * 12
                            if (entryPos + 12 > jpeg.size) break
                            val tag = readUint16(jpeg, entryPos, littleEndian)
                            if (tag == 0x0112) {
                                val orientation = readUint16(jpeg, entryPos + 8, littleEndian)
                                return when (orientation) {
                                    3 -> 180
                                    6 -> 90
                                    8 -> 270
                                    else -> 0
                                }
                            }
                        }
                    }
                }
                offset += 2 + segLen
            }
        } catch (_: Throwable) {
        }
        return 0
    }

    private fun readUint16(b: ByteArray, pos: Int, littleEndian: Boolean): Int {
        return if (littleEndian) {
            (b[pos].toInt() and 0xFF) or ((b[pos + 1].toInt() and 0xFF) shl 8)
        } else {
            ((b[pos].toInt() and 0xFF) shl 8) or (b[pos + 1].toInt() and 0xFF)
        }
    }

    private fun readInt32(b: ByteArray, pos: Int, littleEndian: Boolean): Int {
        return if (littleEndian) {
            (b[pos].toInt() and 0xFF) or
                ((b[pos + 1].toInt() and 0xFF) shl 8) or
                ((b[pos + 2].toInt() and 0xFF) shl 16) or
                ((b[pos + 3].toInt() and 0xFF) shl 24)
        } else {
            ((b[pos].toInt() and 0xFF) shl 24) or
                ((b[pos + 1].toInt() and 0xFF) shl 16) or
                ((b[pos + 2].toInt() and 0xFF) shl 8) or
                (b[pos + 3].toInt() and 0xFF)
        }
    }

    override fun onDestroy() {
        imageDecodeExecutor.shutdownNow()
        super.onDestroy()
    }
}
