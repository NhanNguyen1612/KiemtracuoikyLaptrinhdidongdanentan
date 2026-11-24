# GÓI DỰ ÁN VÀ BẢN CÀI ĐẶT RESQ-AID (PRODUCTION RUNNABLE PACKAGE)

Thư mục này được tinh gọn độc lập, **chỉ chứa mã nguồn dự án để chạy và bản cài đặt APK chính thức**, hoàn toàn loại bỏ các file rác và file huấn luyện trung gian.

---

## 📁 CẤU TRÚC THƯ MỤC
```
ResQ-Aid-Production-App/
├── APK/
│   ├── ResQ-Aid-latest-release.apk    (Bản cài đặt APK phát hành tối ưu 33.28 MB, ARM64)
│   └── CAI_DAT_APK_QUA_ADB.bat        (Script 1-click cài đặt trực tiếp vào điện thoại)
├── ResQ-Aid-Mobile/                   (Toàn bộ mã nguồn dự án Flutter sạch sẽ, chuẩn Clean Architecture)
│   ├── android/                       (Cấu hình Gradle, NDK và Camera native)
│   ├── assets/                        (Mô hình MobileNetV3 TFLite, cơ sở dữ liệu bệnh viện SQLite, âm thanh Metronome)
│   ├── lib/                           (Mã nguồn Dart: Tầng Presentation, Domain, Data & AI Engine)
│   ├── test/                          (Bộ kiểm thử tự động 46 Unit Tests & 94 Ca Benchmark)
│   ├── pubspec.yaml                   (Khai báo thư viện phụ thuộc)
│   └── README.md
├── CHAY_UNG_DUNG.bat                  (Script 1-click tự động chạy ứng dụng trên thiết bị)
└── HUONG_DAN_CHAY_PROJECT.md          (Tài liệu hướng dẫn này)
```

---

## 🚀 CÁCH 1: CÀI ĐẶT VÀ TRẢI NGHIỆM NGAY FILE APK (KHÔNG CẦN CÀI FLUTTER)
1. Kết nối điện thoại Android với máy tính qua cáp USB (đã bật chế độ `Gỡ lỗi USB / USB Debugging`).
2. Vào thư mục `APK` và nhấp đúp chạy file `CAI_DAT_APK_QUA_ADB.bat`.
3. Hoặc chép trực tiếp file `ResQ-Aid-latest-release.apk` vào điện thoại (qua Zalo/Drive/cáp OTG) và nhấn Cài đặt (Install).

---

## 💻 CÁCH 2: MỞ VÀ CHẠY PROJECT MÃ NGUỒN (VS CODE / ANDROID STUDIO / TERMINAL)

### Cách 2.1: Chạy bằng file lệnh tự động
* Nhấp đúp chuột vào file `CHAY_UNG_DUNG.bat` ở thư mục gốc.

### Cách 2.2: Chạy qua VS Code hoặc Android Studio
1. Mở **VS Code** hoặc **Android Studio**.
2. Chọn **Open Folder** và trỏ đến thư mục: `ResQ-Aid-Mobile`.
3. Mở terminal trong thư mục này và chạy:
   ```bash
   flutter pub get
   flutter run
   ```
4. Để chạy toàn bộ kiểm thử Unit Test và 94 ca Benchmark lâm sàng:
   ```bash
   flutter test test/voice_dialogue_test.dart
   flutter test test/benchmark_comprehensive_audit_test.dart
   ```
