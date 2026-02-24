@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo 瞬 - 智能打包脚本 V1.0.3
echo ========================================
echo.

REM 当前版本号（每次更新时修改这里）
set CURRENT_VERSION=1.0.3

REM 设置Flutter中国镜像
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn

REM 设置Gradle镜像
set GRADLE_USER_HOME=%USERPROFILE%\.gradle
set GRADLE_OPTS=-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true

REM 直接设置Flutter路径
set FLUTTER_BIN=D:\flutter_windows_3.27.1-stable\flutter\bin
set PATH=%FLUTTER_BIN%;%PATH%

echo 当前版本: V%CURRENT_VERSION%
echo Flutter路径: %FLUTTER_BIN%
echo 使用中国镜像: %FLUTTER_STORAGE_BASE_URL%
echo.

cd /d "%~dp0flutter-app"

echo [1/4] 清理构建缓存...
call "%FLUTTER_BIN%\flutter.bat" clean
echo.

echo [2/4] 获取依赖包...
call "%FLUTTER_BIN%\flutter.bat" pub get
echo.

echo [3/4] 开始构建APK...
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
    pause
    exit /b 1
)

echo.
echo ✅ 构建完成！
echo.

echo [4/4] 复制APK并创建版本文档...
set OUTPUT_DIR=..\apk-output
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set APK_SOURCE=build\app\outputs\flutter-apk\app-release.apk
set APK_TARGET=%OUTPUT_DIR%\瞬-v%CURRENT_VERSION%-release.apk

if exist "%APK_SOURCE%" (
    copy /Y "%APK_SOURCE%" "%APK_TARGET%"
    echo ✅ APK已复制到: %APK_TARGET%
    
    REM 创建版本文档目录
    set VERSION_DIR=..\versions\v%CURRENT_VERSION%
    if not exist "!VERSION_DIR!" (
        mkdir "!VERSION_DIR!"
        echo ✅ 已创建版本文档目录: v%CURRENT_VERSION%
        
        REM 创建版本文档模板
        call :create_version_docs "!VERSION_DIR!"
    )
    
    echo.
    echo ========================================
    echo ✅ 打包完成！V%CURRENT_VERSION%
    echo ========================================
    echo.
    echo APK位置: %CD%\%OUTPUT_DIR%\瞬-v%CURRENT_VERSION%-release.apk
    echo 版本文档: %CD%\!VERSION_DIR!\
    echo.
    echo 📝 下一步：
    echo 1. 更新版本文档（versions\v%CURRENT_VERSION%\）
    echo 2. 更新 CHANGELOG.md
    echo 3. 测试APK功能
    echo.
    echo 按任意键打开APK文件夹...
    pause >nul
    explorer "%CD%\%OUTPUT_DIR%\"
) else (
    echo ❌ 错误：找不到APK文件！
    pause
    exit /b 1
)

exit /b 0

:create_version_docs
set DOC_DIR=%~1

REM 创建README.md
(
echo # 瞬 V%CURRENT_VERSION% 版本文档
echo.
echo ## 版本信息
echo - 版本号：V%CURRENT_VERSION%
echo - 发布日期：%date%
echo - 构建时间：%time%
echo.
echo ## 文档列表
echo - [版本说明](./瞬-v%CURRENT_VERSION%-版本说明.md^)
echo - [PRD文档](./瞬-v%CURRENT_VERSION%-PRD.md^)
echo - [开发文档](./瞬-v%CURRENT_VERSION%-开发文档.md^)
echo - [Bug修复记录](./瞬-v%CURRENT_VERSION%-Bug修复记录.md^)
echo - [测试报告](./瞬-v%CURRENT_VERSION%-测试报告.md^)
echo.
echo ## 快速链接
echo - APK文件：`../../apk-output/瞬-v%CURRENT_VERSION%-release.apk`
echo - 源码目录：`../../flutter-app/`
) > "%DOC_DIR%\README.md"

REM 创建版本说明模板
(
echo # 瞬 V%CURRENT_VERSION% 版本说明
echo.
echo ## 📋 版本信息
echo - **版本号**：V%CURRENT_VERSION%
echo - **发布日期**：%date%
echo - **版本类型**：正式版
echo.
echo ## ✨ 新增功能
echo - [ ] 功能1
echo - [ ] 功能2
echo.
echo ## 🐛 Bug修复
echo - [ ] 修复1
echo - [ ] 修复2
echo.
echo ## 🔧 优化改进
echo - [ ] 优化1
echo - [ ] 优化2
echo.
echo ## 📦 APK信息
echo - **文件名**：瞬-v%CURRENT_VERSION%-release.apk
echo - **文件大小**：待更新
echo - **最低Android版本**：5.0 (API 21^)
echo.
echo ## 🔗 相关链接
echo - [完整PRD文档](./瞬-v%CURRENT_VERSION%-PRD.md^)
echo - [开发文档](./瞬-v%CURRENT_VERSION%-开发文档.md^)
echo - [Bug修复记录](./瞬-v%CURRENT_VERSION%-Bug修复记录.md^)
) > "%DOC_DIR%\瞬-v%CURRENT_VERSION%-版本说明.md"

REM 创建Bug修复记录模板
(
echo # 瞬 V%CURRENT_VERSION% Bug修复记录
echo.
echo ## 修复日期：%date%
echo.
echo ---
echo.
echo ## 🐛 Bug列表
echo.
echo ### Bug #1: [Bug标题]
echo - **发现时间**：
echo - **严重程度**：高/中/低
echo - **影响范围**：
echo - **问题描述**：
echo - **复现步骤**：
echo   1. 步骤1
echo   2. 步骤2
echo - **修复方案**：
echo - **修复文件**：
echo - **测试结果**：✅ 已修复
echo.
echo ---
) > "%DOC_DIR%\瞬-v%CURRENT_VERSION%-Bug修复记录.md"

REM 创建测试报告模板
(
echo # 瞬 V%CURRENT_VERSION% 测试报告
echo.
echo ## 测试信息
echo - **测试日期**：%date%
echo - **测试版本**：V%CURRENT_VERSION%
echo - **测试人员**：
echo.
echo ## 测试环境
echo - **测试设备**：
echo - **Android版本**：
echo - **屏幕分辨率**：
echo.
echo ## 功能测试
echo.
echo ### 1. 登录注册
echo - [ ] 手机号登录
echo - [ ] 验证码验证
echo - [ ] 用户协议查看
echo.
echo ### 2. 匹配功能
echo - [ ] 开始匹配
echo - [ ] 取消匹配
echo - [ ] 匹配成功
echo - [ ] 打招呼
echo.
echo ### 3. 聊天功能
echo - [ ] 发送消息
echo - [ ] 接收消息
echo - [ ] 消息状态显示
echo - [ ] 亲密度系统
echo.
echo ### 4. 好友功能
echo - [ ] 添加好友
echo - [ ] 好友列表
echo - [ ] 取关功能
echo.
echo ## 测试结果
echo - **通过率**：
echo - **发现Bug数**：
echo - **严重Bug数**：
echo.
echo ## 测试结论
echo ✅ 通过 / ❌ 不通过
) > "%DOC_DIR%\瞬-v%CURRENT_VERSION%-测试报告.md"

echo ✅ 版本文档模板已创建
exit /b 0

