@echo off
chcp 65001 >nul
echo ========================================
echo 瞬 - 本地Gradle打包 V1.0.2
echo ========================================
echo.

REM 设置Flutter中国镜像
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn

REM 设置Flutter路径
set FLUTTER_BIN=D:\flutter_windows_3.27.1-stable\flutter\bin
set PATH=%FLUTTER_BIN%;%PATH%

REM 设置本地Gradle路径
set GRADLE_HOME=C:\Users\chenjiageng\.gradle\wrapper\dists\gradle-8.4-all\8bq4mb83wz2dwo2fvpnuek2vl\gradle-8.4
set PATH=%GRADLE_HOME%\bin;%PATH%

echo Flutter路径: %FLUTTER_BIN%
echo Gradle路径: %GRADLE_HOME%
echo.

cd /d "%~dp0flutter-app"

echo [1/4] 清理构建缓存...
call "%FLUTTER_BIN%\flutter.bat" clean
echo ✅ 清理完成！
echo.

echo [2/4] 获取依赖包...
call "%FLUTTER_BIN%\flutter.bat" pub get
echo ✅ 依赖获取完成！
echo.

echo [3/4] 开始构建APK（使用本地Gradle）...
echo 这可能需要几分钟，请耐心等待...
echo.

cd android
call gradle assembleRelease
set BUILD_RESULT=%ERRORLEVEL%
cd ..

if %BUILD_RESULT% NEQ 0 (
    echo.
    echo ❌ 构建失败！
    pause
    exit /b 1
)

echo ✅ 构建完成！
echo.

echo [4/4] 复制APK到输出目录...
set OUTPUT_DIR=..\apk-output
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set APK_SOURCE=build\app\outputs\flutter-apk\app-release.apk
set APK_TARGET=%OUTPUT_DIR%\瞬-v1.0.2-release.apk

if exist "%APK_SOURCE%" (
    copy /Y "%APK_SOURCE%" "%APK_TARGET%"
    echo ✅ APK已复制到: %APK_TARGET%
    echo.
    echo ========================================
    echo ✅ 打包完成！
    echo ========================================
    echo.
    echo APK位置: %CD%\%OUTPUT_DIR%\瞬-v1.0.2-release.apk
    echo.
    echo 按任意键打开APK文件夹...
    pause >nul
    explorer "%CD%\%OUTPUT_DIR%\"
) else (
    echo ❌ 错误：找不到APK文件！
    pause
    exit /b 1
)

