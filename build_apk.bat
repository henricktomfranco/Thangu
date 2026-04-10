@echo off
REM Build Flutter Android APK Script for Thangu
REM Sets up Java environment and builds APK

setlocal enabledelayedexpansion

REM Configuration
set "ANDROID_STUDIO_PATH=D:\Program Files\AndroidStudio"
set "PROJECT_PATH=C:\Go\Thangu"
set "DEBUG_BUILD=0"

REM Parse arguments
if "%1"=="--debug" set "DEBUG_BUILD=1"
if "%1"=="-d" set "DEBUG_BUILD=1"

REM Verify paths exist
if not exist "!ANDROID_STUDIO_PATH!" (
    echo Error: Android Studio not found at !ANDROID_STUDIO_PATH!
    pause
    exit /b 1
)

if not exist "!PROJECT_PATH!" (
    echo Error: Project not found at !PROJECT_PATH!
    pause
    exit /b 1
)

REM Set JAVA_HOME
set "JAVA_HOME=!ANDROID_STUDIO_PATH!\jbr"
if not exist "!JAVA_HOME!" (
    echo Error: Java JBR not found at !JAVA_HOME!
    pause
    exit /b 1
)

echo.
echo ==========================================
echo  Flutter Android APK Build Script
echo ==========================================
echo.
echo Java Home: !JAVA_HOME!
echo Project:  !PROJECT_PATH!
echo.

REM Change to project directory
cd /d "!PROJECT_PATH!" || (
    echo Error: Cannot change to project directory
    pause
    exit /b 1
)

REM Step 1: Flutter Clean
echo Step 1: Cleaning Flutter cache...
call flutter clean
if !errorlevel! neq 0 (
    echo Error: flutter clean failed
    pause
    exit /b 1
)
echo Success: Flutter cache cleaned

REM Step 2: Gradle Clean
echo.
echo Step 2: Cleaning Gradle cache...
cd /d "!PROJECT_PATH!\android" || goto error
call gradlew clean
if !errorlevel! neq 0 (
    echo Error: gradlew clean failed
    cd /d "!PROJECT_PATH!"
    pause
    exit /b 1
)
echo Success: Gradle cache cleaned
cd /d "!PROJECT_PATH!"

REM Step 3: Get Dependencies
echo.
echo Step 3: Getting dependencies...
call flutter pub get
if !errorlevel! neq 0 (
    echo Error: flutter pub get failed
    pause
    exit /b 1
)
echo Success: Dependencies downloaded

REM Step 4: Build APK
echo.
echo Step 4: Building APK...
if !DEBUG_BUILD! equ 1 (
    echo Building DEBUG APK...
    call flutter build apk
) else (
    echo Building RELEASE APK...
    call flutter build apk --release
)

if !errorlevel! neq 0 (
    echo Error: APK build failed
    pause
    exit /b 1
)

echo.
echo ==========================================
echo  Build Completed Successfully!
echo ==========================================
echo.

REM Show APK location
if !DEBUG_BUILD! equ 1 (
    set "APK_PATH=!PROJECT_PATH!\build\app\outputs\flutter-apk\app-debug.apk"
    echo Debug APK: !APK_PATH!
) else (
    set "APK_PATH=!PROJECT_PATH!\build\app\outputs\flutter-apk\app-release.apk"
    echo Release APK: !APK_PATH!
)

if exist "!APK_PATH!" (
    for /F "usebackq" %%A in ('!APK_PATH!') do set /A "SIZE_MB=%%~zA/1048576"
    echo File size: !SIZE_MB! MB
    echo.
    echo APK is ready for installation!
) else (
    echo Error: APK not found
    pause
    exit /b 1
)

echo.
pause
exit /b 0

:error
echo Error occurred. Press any key to exit...
pause
exit /b 1
