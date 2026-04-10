# APK Installation Troubleshooting Guide

## Problem: "App not installed" error on Android device

This error appears when Android can't install the APK. Here are the most common causes and solutions.

---

## Quick Fix (Try These First)

### 1. **Uninstall the old app**
If you previously installed an older version, it might have a different signature:

```
Device Settings → Apps → Thangu → Uninstall
```

Then try installing the new APK again.

### 2. **Enable Installation from Unknown Sources**
- **Android 8.0 and below:**
  ```
  Settings → Security → Allow installation from Unknown sources (Toggle ON)
  ```

- **Android 9+:**
  ```
  Settings → Apps & notifications → Advanced → Special app access → Install unknown apps
  → Select your File Manager → Toggle ON
  ```

### 3. **Check Storage Space**
Your device needs at least 100 MB free space.
```
Settings → Storage → Check available space
```

---

## Using ADB to Install (Most Reliable)

If the above doesn't work, use ADB (Android Debug Bridge):

### Step 1: Enable USB Debugging on Device
```
Device → Settings → Developer Options → USB Debugging (Toggle ON)
```

If Developer Options isn't visible:
```
Settings → About Phone → Tap "Build Number" 7 times
→ Developer Options will appear in Settings
```

### Step 2: Connect Device via USB
Plug in your Android device with a USB cable.

### Step 3: Use the Installation Script
Run the automatic installation script:
```bash
cd C:\Go\Thangu
install_apk.bat
```

This script will:
- Verify device connection
- Show device information
- Uninstall old version (optional)
- Install the new APK via ADB

### Step 4: Manual ADB Installation
If the script doesn't work:

```bash
# Check connected devices
adb devices

# Uninstall old app (if needed)
adb uninstall com.example.thangu

# Install APK
adb install -r build\app\outputs\flutter-apk\app-release.apk

# For debug APK
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## Device Compatibility Check

Your app requires:
- **Minimum API Level:** Android 5.0 (API 21)
- **Target API Level:** Latest available

Check your device's API level:
```bash
adb shell getprop ro.build.version.sdk
```

**Must be API 21 or higher**

---

## Common Error Messages

### "Installation failed due to invalid APK"
- APK file is corrupted
- **Solution:** Rebuild using `build_apk.bat`

### "App conflicts with existing installation"
- Different version already installed
- **Solution:** Uninstall via Settings or `adb uninstall com.example.thangu`

### "Insufficient storage space"
- Device storage is full
- **Solution:** Free up at least 100 MB

### "Unknown error: 0x80004005"
- Windows/ADB communication issue
- **Solution:** Reconnect device, restart ADB, use USB 2.0 port

### "Not enough space or corrupted SD card"
- Internal storage issue
- **Solution:** Factory reset or check device storage

---

## Debugging Steps

### 1. Check APK File Size
```bash
# Should be around 50 MB
dir build\app\outputs\flutter-apk\app-release.apk
```

### 2. Verify Device Connection
```bash
# Check if device is recognized
adb devices

# Test communication
adb shell
```

### 3. Check Device Logs
```bash
# View installation logs
adb logcat | findstr "Thangu\|staging"
```

### 4. Install Debug APK
Debug APKs sometimes work better for initial testing:
```bash
# Build debug version
build_apk.bat --debug

# Install debug APK
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## If Nothing Works

### Try These Last Resort Options:

1. **Factory Reset Device** (if safe)
   - Back up important data first
   - Settings → System → Reset Options → erase all data

2. **Use Different Device**
   - Try on another Android device or emulator
   - This helps determine if it's device-specific

3. **Check with Android Studio Emulator**
   ```bash
   flutter run
   # Select emulator instead of physical device
   ```

4. **Verify Project Configuration**
   File: `android/app/build.gradle.kts`
   - Check `applicationId = "com.example.thangu"`
   - Verify `minSdk` matches device API level
   - Confirm `targetSdk` is compatible

---

## Build Variants to Try

### Release APK (Optimized)
```bash
build_apk.bat
```
- Smaller file size (~50 MB)
- Optimized for performance
- Uses debug signing (for testing)

### Debug APK (More Compatible)
```bash
build_apk.bat --debug
```
- Larger file size (~60 MB)
- Better error logging
- Sometimes installs when release fails

### Via Flutter Directly
```bash
flutter install
# Requires connected device
```

---

## Installation Success Indicators

✅ **"Success" or "Success: Package installed"** - APK installed correctly

✅ **App appears in Settings → Apps** - Installation confirmed

✅ **App launches on device** - Fully functional

---

## Need More Help?

If you still can't install, provide:
1. Exact error message from installation
2. Device model and Android version (API level)
3. Output from: `adb logcat --last 100`
4. Output from: `adb shell getprop | grep -E "ro.build|version"`
5. APK file size and location

---

## Quick Command Reference

```bash
# Uninstall
adb uninstall com.example.thangu

# Install Release
adb install -r build\app\outputs\flutter-apk\app-release.apk

# Install Debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk

# Force Reinstall (removes old version)
adb install -r --replace build\app\outputs\flutter-apk\app-release.apk

# Check Device
adb devices
adb shell getprop ro.build.version.sdk

# View Logs
adb logcat

# Open App
adb shell am start -n com.example.thangu/.MainActivity
```

---

**Remember:** Always uninstall the old version before installing a new one if you changed anything in the Android manifest or build configuration.
