@echo off
chcp 65001 > nul
echo ====================================================
echo   KHỞI ĐỘNG ỨNG DỤNG RESQ-AID TRÊN THIẾT BỊ / MÁY ẢO
echo ====================================================
cd /d "%~dp0ResQ-Aid-Mobile"
echo [1/2] Kiểm tra kết nối thiết bị Flutter...
call flutter devices
echo.
echo [2/2] Chạy ứng dụng ở chế độ Debug/Hot Reload...
call flutter run
pause
