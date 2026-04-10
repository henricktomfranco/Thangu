@echo off
REM PowerShell script launcher for building Flutter Android APK
REM This batch file allows running the PowerShell script without manual execution policy changes

setlocal enabledelayedexpansion

REM Define paths
set "ANDROID_STUDIO_PATH=D:\Program Files\AndroidStudio"
set "PROJECT_PATH=C:\Go\Thangu"

REM Check if paths exist
if not exist "%ANDROID_STUDIO_PATH%" (
    echo Error: Android Studio path not found: %ANDROID_STUDIO_PATH%
    pause
    exit /b 1
)

if not exist "%PROJECT_PATH%" (
    echo Error: Project path not found: %PROJECT_PATH%
    pause
    exit /b 1
)

REM Run the PowerShell script
echo Building Flutter Android APK...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_PATH%\build_apk.ps1" -AndroidStudioPath "%ANDROID_STUDIO_PATH%" -ProjectPath "%PROJECT_PATH%"

if %errorlevel% neq 0 (
    echo.
    echo Build failed! Press any key to exit...
    pause
    exit /b 1
)

echo.
echo Build completed! Press any key to exit...
pause
exit /b 0
