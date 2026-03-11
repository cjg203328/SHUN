@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "BASE_URL=%~1"

if "%BASE_URL%"=="" (
  set /p BASE_URL=请输入内网穿透 HTTPS 地址（例如 https://demo.example.com）: 
)

if "%BASE_URL%"=="" (
  echo [ERROR] 未输入地址，已取消。
  pause
  exit /b 1
)

if /I not "%BASE_URL:~0,8%"=="https://" (
  echo [ERROR] 区域测试建议必须使用 HTTPS 地址，否则 Android 真机可能拦截明文流量。
  echo         你输入的是：%BASE_URL%
  pause
  exit /b 1
)

if "%BASE_URL:~-1%"=="/" set "BASE_URL=%BASE_URL:~0,-1%"

set "SUNLIAO_API_BASE_URL=%BASE_URL%/api/v1"
set "SUNLIAO_MEDIA_BASE_URL=%BASE_URL%/media"

echo ========================================
echo Sunliao 区域测试打包
echo ========================================
echo Tunnel Base URL : %BASE_URL%
echo API Base URL    : %SUNLIAO_API_BASE_URL%
echo Media Base URL  : %SUNLIAO_MEDIA_BASE_URL%
echo.

call "%~dp0build.bat" apk
exit /b %errorlevel%
