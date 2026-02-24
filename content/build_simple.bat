@echo off
chcp 65001 >nul
echo ========================================
echo 瞬 - 简化打包脚本 V1.0.2
echo ========================================
echo.

REM 设置Flutter中国镜像
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn

REM 设置Gradle镜像
set GRADLE_USER_HOME=%USERPROFILE%\.gradle
set GRADLE_OPTS=-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true

REM 直接设置Flutter路径
set FLUTTER_BIN=D:\flutter_windows_3.27.1-stable\flutter\bin
set PATH=%FLUTTER_BIN%;%PATH%

echo Flutter路径: %FLUTTER_BIN%
echo 使用中国镜像: %FLUTTER_STORAGE_BASE_URL%
echo.

cd /d "%~dp0flutter-app"

echo [1/3] 清理构建缓存...
call "%FLUTTER_BIN%\flutter.bat" clean
echo.

echo [2/3] 获取依赖包...
call "%FLUTTER_BIN%\flutter.bat" pub get
echo.

echo [3/3] 开始构建APK（使用本地Gradle）...
echo 这可能需要较长时间，请耐心等待...
echo.

REM 使用Android Studio自带的Gradle
set ANDROID_STUDIO_GRADLE=C:\Program Files\Android\Android Studio\gradle\gradle-8.9\bin\gradle.bat

if exist "%ANDROID_STUDIO_GRADLE%" (
    echo 使用Android Studio自带的Gradle
    cd android
    call "%ANDROID_STUDIO_GRADLE%" assembleRelease
    cd ..
) else (
    echo 使用Flutter自带的Gradle
    call "%FLUTTER_BIN%\flutter.bat" build apk --release
)

if errorlevel 1 (
    echo.
    echo ❌ 构建失败！
    echo.
    echo 建议：
    echo 1. 检查网络连接
    echo 2. 如果有VPN，请开启后重试
    echo 3. 或者等待网络稳定后重试
    echo.
    pause
    exit /b 1
)

echo.
echo ✅ 构建完成！
echo.

set OUTPUT_DIR=..\apk-output
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set APK_SOURCE=build\app\outputs\flutter-apk\app-release.apk
set APK_TARGET=%OUTPUT_DIR%\瞬-v1.0.2-release.apk

if exist "%APK_SOURCE%" (
    copy /Y "%APK_SOURCE%" "%APK_TARGET%"
    echo ✅ APK已复制到: %APK_TARGET%
    echo.
    echo 文件位置: %CD%\%OUTPUT_DIR%\瞬-v1.0.2-release.apk
    echo.
    echo 按任意键打开APK文件夹...
    pause >nul
    explorer "%CD%\%OUTPUT_DIR%\"
) else (
    echo ❌ 错误：找不到APK文件！
    pause
    exit /b 1
)

