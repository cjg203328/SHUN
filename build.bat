@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "VERSION=1.0.4"
set "BUILD_TARGET=%~1"
if "%BUILD_TARGET%"=="" set "BUILD_TARGET=apk"
set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%flutter-app"
set "OUTPUT_DIR=%SCRIPT_DIR%apk-output"
set "FLUTTER_CMD=D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat"
set "ALLOW_DEBUG_RELEASE_SIGNING=true"
set "DART_DEFINE_ARG="
set "ORG_GRADLE_PROJECT_sunliaoAllowDebugReleaseSigning=%ALLOW_DEBUG_RELEASE_SIGNING%"

if /I not "%BUILD_TARGET%"=="apk" if /I not "%BUILD_TARGET%"=="aab" (
  echo [ERROR] Unsupported build target: %BUILD_TARGET%
  echo Usage: build.bat [apk^|aab]
  pause
  exit /b 1
)

if defined SUNLIAO_API_BASE_URL (
  set "DART_DEFINE_ARG=--dart-define=SUNLIAO_API_BASE_URL=%SUNLIAO_API_BASE_URL%"
)

if defined SUNLIAO_MEDIA_BASE_URL (
  set "DART_DEFINE_ARG=%DART_DEFINE_ARG% --dart-define=SUNLIAO_MEDIA_BASE_URL=%SUNLIAO_MEDIA_BASE_URL%"
)

if /I "%BUILD_TARGET%"=="apk" (
  set "ARTIFACT_NAME=shun-v%VERSION%-release.apk"
  set "BUILD_COMMAND=build apk --release"
  set "ARTIFACT_SOURCE=%APP_DIR%\build\app\outputs\flutter-apk\app-release.apk"
) else (
  set "ARTIFACT_NAME=shun-v%VERSION%-release.aab"
  set "BUILD_COMMAND=build appbundle --release"
  set "ARTIFACT_SOURCE=%APP_DIR%\build\app\outputs\bundle\release\app-release.aab"
)

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
echo Sunliao V%VERSION% One-Click Release Build
echo ========================================
echo Flutter: %FLUTTER_CMD%
echo App: %APP_DIR%
echo Target: %BUILD_TARGET%
if defined SUNLIAO_API_BASE_URL echo API Base URL: %SUNLIAO_API_BASE_URL%
if defined SUNLIAO_MEDIA_BASE_URL echo Media Base URL: %SUNLIAO_MEDIA_BASE_URL%

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
echo [3/4] flutter %BUILD_COMMAND%...
call "%FLUTTER_CMD%" %BUILD_COMMAND% %DART_DEFINE_ARG% --dart-define=SUNLIAO_RELEASE_BUILD=true
if errorlevel 1 goto :error

echo.
echo [4/4] Copy artifact...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
copy /Y "%ARTIFACT_SOURCE%" "%OUTPUT_DIR%\%ARTIFACT_NAME%" >nul
if errorlevel 1 goto :error

echo.
echo ========================================
echo BUILD SUCCESS
echo ========================================
echo Artifact: %OUTPUT_DIR%\%ARTIFACT_NAME%
if "%ALLOW_DEBUG_RELEASE_SIGNING%"=="true" echo [WARN] Built with debug signing fallback. Configure flutter-app\android\key.properties before production release.
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
