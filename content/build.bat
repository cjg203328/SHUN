@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "VERSION=1.0.3"
set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%flutter-app"
set "OUTPUT_DIR=%SCRIPT_DIR%apk-output"
set "FLUTTER_CMD=D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat"
set "APK_NAME=shun-v%VERSION%-release.apk"

if not exist "%APP_DIR%\pubspec.yaml" (
  echo [ERROR] flutter-app directory is missing: %APP_DIR%
  pause
  exit /b 1
)

if not exist "%FLUTTER_CMD%" (
  for /f "delims=" %%i in ('where flutter 2^>nul') do (
    if not defined FLUTTER_CMD set "FLUTTER_CMD=%%i"
  )
)

if not exist "%FLUTTER_CMD%" (
  echo [ERROR] Flutter not found.
  echo Please update FLUTTER_CMD in build.bat or add flutter to PATH.
  pause
  exit /b 1
)

echo ========================================
echo Sunliao V%VERSION% One-Click APK Build
echo ========================================
echo Flutter: %FLUTTER_CMD%
echo App: %APP_DIR%

pushd "%APP_DIR%"
if errorlevel 1 (
  echo [ERROR] Failed to enter app directory: %APP_DIR%
  pause
  exit /b 1
)

echo.
echo [1/4] flutter clean...
call "%FLUTTER_CMD%" clean
if errorlevel 1 goto :error

echo.
echo [2/4] flutter pub get...
call "%FLUTTER_CMD%" pub get
if errorlevel 1 goto :error

echo.
echo [3/4] flutter build apk --release...
call "%FLUTTER_CMD%" build apk --release
if errorlevel 1 goto :error

echo.
echo [4/4] Copy APK...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
copy /Y "%APP_DIR%\build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\%APK_NAME%" >nul
if errorlevel 1 goto :error

echo.
echo ========================================
echo BUILD SUCCESS
echo ========================================
echo APK: %OUTPUT_DIR%\%APK_NAME%
echo.
popd
pause
exit /b 0

:error
popd
echo.
echo ========================================
echo BUILD FAILED
echo ========================================
echo.
pause
exit /b 1
