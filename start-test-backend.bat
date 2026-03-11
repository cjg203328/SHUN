@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "SERVER_DIR=%SCRIPT_DIR%backend\server"
set "PORT_ARG=%~1"

if "%PORT_ARG%"=="" set "PORT_ARG=3000"

if not exist "%SERVER_DIR%\package.json" (
  echo [ERROR] Backend directory not found: %SERVER_DIR%
  pause
  exit /b 1
)

if not exist "%SERVER_DIR%\node_modules" (
  echo [ERROR] backend/server/node_modules is missing.
  echo Run these commands first:
  echo   cd backend\server
  echo   npm install
  pause
  exit /b 1
)

set "APP_ENV=development"
set "PORT=%PORT_ARG%"
set "USER_STORE_DRIVER=memory"
set "AUTH_RUNTIME_DRIVER=memory"
set "RUNTIME_STATE_DRIVER=memory"

title Sunliao Backend Test Server
echo ========================================
echo Sunliao Backend Test Server
echo ========================================
echo Server Dir           : %SERVER_DIR%
echo Port                 : %PORT%
echo USER_STORE_DRIVER    : %USER_STORE_DRIVER%
echo AUTH_RUNTIME_DRIVER  : %AUTH_RUNTIME_DRIVER%
echo RUNTIME_STATE_DRIVER : %RUNTIME_STATE_DRIVER%
echo Test OTP Code        : 123456
echo Swagger URL          : http://127.0.0.1:%PORT%/api/docs
echo.

pushd "%SERVER_DIR%"
call npm.cmd run start
set "EXIT_CODE=%errorlevel%"
popd

echo.
if not "%EXIT_CODE%"=="0" (
  echo [ERROR] Backend exited with code %EXIT_CODE%
  pause
)

exit /b %EXIT_CODE%
