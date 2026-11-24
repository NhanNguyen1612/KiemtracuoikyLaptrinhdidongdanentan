@echo off
chcp 65001 > nul
echo ====================================================
echo   CÀI ĐẶT BẢN RELEASE APK RESQ-AID VÀO ĐIỆN THOẠI
echo ====================================================
cd /d "%~dp0"
adb devices
echo Đang cài đặt ResQ-Aid-latest-release.apk...
adb install -r ResQ-Aid-latest-release.apk
echo Hoàn tất!
pause
