@echo off
REM APK Installation Troubleshooting Script
REM This script helps diagnose and fix APK installation issues

setlocal enabledelayedexpansion

echo.
echo =========================================
echo  APK Installation Troubleshooting
echo =========================================
echo.

REM Check if ADB is available
where adb >nul 2>&1
if errorlevel 1 (
    echo Error: ADB not found in PATH
    echo.
    echo Please add Android SDK tools to your PATH:
    echo Android Studio is typically in:
    echo   D:\Program Files\AndroidStudio\platform-tools
    echo.
    echo Or run from Android Studio's command line tools
    pause
    exit /b 1
)

REM Check if device is connected
echo Checking for connected devices...
adb devices
echo.

set /p device_choice="Is your device listed above? (y/n): "
if /i not "%device_choice%"=="y" (
    echo Please connect your Android device via USB and enable USB debugging.
    echo Settings ^> Developer Options ^> USB Debugging
    pause
    exit /b 1
)

echo.
echo Getting device information...
for /f "delims=" %%A in ('adb shell getprop ro.build.version.sdk') do set "API_LEVEL=%%A"
for /f "delims=" %%A in ('adb shell getprop ro.product.model') do set "DEVICE_MODEL=%%A"
for /f "delims=" %%A in ('adb shell getprop ro.product.manufacturer') do set "MANUFACTURER=%%A"

echo.
echo Device Info:
echo - Model: !DEVICE_MODEL!
echo - Manufacturer: !MANUFACTURER!
echo - API Level: !API_LEVEL!
echo.

REM Check available storage
for /f "delims=" %%A in ('adb shell df /data ^| findstr /R "[0-9]"') do (
    set "storage=%%A"
)
echo Storage Info:
echo !storage!
echo.

REM Uninstall old app
set /p uninstall="Uninstall existing app first? (y/n): "
if /i "%uninstall%"=="y" (
    echo Uninstalling com.example.thangu...
    adb uninstall com.example.thangu
    echo Done.
    echo.
)

REM Choose which APK to install
echo.
echo Which APK would you like to install?
echo 1. Release APK (recommended)
echo 2. Debug APK (if release doesn't work)
echo 3. Exit
echo.
set /p choice="Enter choice (1-3): "

if "%choice%"=="1" (
    set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"
) else if "%choice%"=="2" (
    set "APK_PATH=build\app\outputs\flutter-apk\app-debug.apk"
) else (
    exit /b 0
)

if not exist "!APK_PATH!" (
    echo.
    echo Error: APK not found at !APK_PATH!
    echo Please build the APK first using build_apk.bat
    pause
    exit /b 1
)

echo.
echo Installing: !APK_PATH!
echo.

REM Install with ADB
adb install -r "!APK_PATH!"

if errorlevel 1 (
    echo.
    echo Installation failed. Possible reasons:
    echo - Insufficient storage on device
    echo - Device running incompatible Android version
    echo - Signature mismatch with previously installed app
    echo.
    echo Try:
    echo 1. Uninstall the old app completely
    echo 2. Clear Google Play cache: Settings ^> Apps ^> Google Play ^> Storage ^> Clear Cache
    echo 3. Enable installation from unknown sources
    echo 4. Try again
    echo.
    pause
    exit /b 1
)

echo.
echo Success! App installed.
echo You can now launch the app from your device.
echo.
pause
exit /b 0
