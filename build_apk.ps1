# PowerShell script to build Flutter Android APK correctly
# This script sets up the environment and builds a release APK

param(
    [string]$AndroidStudioPath = "D:\Program Files\AndroidStudio",
    [string]$ProjectPath = "C:\Go\Thangu",
    [switch]$Debug = $false
)

# Color output for better visibility
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "» $Message" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Yellow
}

# Check if paths exist
if (-not (Test-Path $ProjectPath)) {
    Write-Error "Project path not found: $ProjectPath"
    exit 1
}

if (-not (Test-Path $AndroidStudioPath)) {
    Write-Error "Android Studio path not found: $AndroidStudioPath"
    exit 1
}

# Set JAVA_HOME
$javaHome = Join-Path $AndroidStudioPath "jbr"
if (-not (Test-Path $javaHome)) {
    Write-Error "Java JBR not found at: $javaHome"
    exit 1
}

Write-Info "Setting JAVA_HOME=$javaHome"
$env:JAVA_HOME = $javaHome

# Change to project directory
Write-Info "Changing to project directory: $ProjectPath"
Set-Location $ProjectPath

# Step 1: Flutter Clean
Write-Step "Step 1: Cleaning Flutter Build Cache"
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter clean failed"
    exit 1
}
Write-Success "Flutter cache cleaned"

# Step 2: Gradle Clean
Write-Step "Step 2: Cleaning Android Gradle Cache"
Set-Location (Join-Path $ProjectPath "android")
./gradlew clean
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gradle clean failed"
    Set-Location $ProjectPath
    exit 1
}
Write-Success "Gradle cache cleaned"
Set-Location $ProjectPath

# Step 3: Get Dependencies
Write-Step "Step 3: Getting Flutter Dependencies"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter pub get failed"
    exit 1
}
Write-Success "Dependencies downloaded"

# Step 4: Build APK
if ($Debug) {
    Write-Step "Step 4: Building Debug APK"
    flutter build apk
} else {
    Write-Step "Step 4: Building Release APK"
    flutter build apk --release
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "APK build failed"
    exit 1
}

# Success message
Write-Step "Build Completed Successfully!"

if ($Debug) {
    $apkPath = Join-Path $ProjectPath "build\app\outputs\flutter-apk\app-debug.apk"
    Write-Success "Debug APK created at: $apkPath"
} else {
    $apkPath = Join-Path $ProjectPath "build\app\outputs\flutter-apk\app-release.apk"
    Write-Success "Release APK created at: $apkPath"
}

# Get file size
if (Test-Path $apkPath) {
    $fileSize = (Get-Item $apkPath).Length / 1MB
    Write-Info "File size: $([Math]::Round($fileSize, 2)) MB"
    Write-Success "APK is ready for installation!"
} else {
    Write-Error "APK file not found at expected location"
    exit 1
}

Write-Host "`n"
