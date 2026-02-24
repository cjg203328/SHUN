@echo off
chcp 65001 >nul
echo ========================================
echo 瞬 - APK打包脚本 V1.0.2
echo ========================================
echo.

REM 直接设置Flutter路径
set FLUTTER_BIN=D:\flutter_windows_3.27.1-stable\flutter\bin
set PATH=%FLUTTER_BIN%;%PATH%

echo [0/5] 检测Flutter环境...
echo Flutter路径: %FLUTTER_BIN%

REM 验证Flutter是否存在
if not exist "%FLUTTER_BIN%\flutter.bat" (
    echo ❌ 错误：找不到Flutter！
    echo 请检查路径: %FLUTTER_BIN%
    echo.
    pause
    exit /b 1
)

echo ✅ Flutter环境检测成功
echo.

echo [1/5] 清理构建缓存...
cd /d "%~dp0flutter-app"
call "%FLUTTER_BIN%\flutter.bat" clean
if errorlevel 1 (
    echo ❌ 清理失败！
    pause
    exit /b 1
)
echo ✅ 清理完成！
echo.

echo [2/5] 获取依赖包...
call "%FLUTTER_BIN%\flutter.bat" pub get
if errorlevel 1 (
    echo ❌ 获取依赖失败！
    pause
    exit /b 1
)
echo ✅ 依赖获取完成！
echo.

echo [3/5] 开始构建APK...
echo 这可能需要10-20分钟（首次构建），请耐心等待...
call "%FLUTTER_BIN%\flutter.bat" build apk --release
if errorlevel 1 (
    echo ❌ 构建失败！
    pause
    exit /b 1
)
echo ✅ 构建完成！
echo.

echo [4/5] 复制APK到输出目录...
set OUTPUT_DIR=..\apk-output
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set APK_SOURCE=build\app\outputs\flutter-apk\app-release.apk
set APK_TARGET=%OUTPUT_DIR%\瞬-v1.0.2-release.apk

if exist "%APK_SOURCE%" (
    copy /Y "%APK_SOURCE%" "%APK_TARGET%"
    echo ✅ APK已复制到: %APK_TARGET%
) else (
    echo ❌ 错误：找不到APK文件！
    echo 源路径: %APK_SOURCE%
    pause
    exit /b 1
)
echo.

echo [5/5] 显示APK信息...
echo ========================================
echo APK文件名: 瞬-v1.0.2-release.apk
echo 输出路径: %OUTPUT_DIR%
for %%A in ("%APK_TARGET%") do (
    set size=%%~zA
    set /a sizeMB=%%~zA/1024/1024
    echo 文件大小: !sizeMB! MB
)
echo ========================================
echo.

echo ✅ 打包完成！
echo.
echo 📱 下一步：
echo 1. 将APK传输到Android手机
echo 2. 在手机上安装APK
echo 3. 使用验证码 123456 登录测试
echo.
echo APK位置: %CD%\%OUTPUT_DIR%\瞬-v1.0.2-release.apk
echo.
echo 按任意键打开APK文件夹...
pause >nul
explorer "%CD%\%OUTPUT_DIR%\"
