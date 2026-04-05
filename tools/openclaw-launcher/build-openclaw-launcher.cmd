@echo off
setlocal

set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%CSC%" (
  echo csc.exe not found.
  exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "OUTPUT=%SCRIPT_DIR%OpenClawLauncher.exe"
set "STOP_OUTPUT=%SCRIPT_DIR%CloseOpenClawLauncher.exe"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"
set "ROOT_OUTPUT=%REPO_ROOT%\OpenClawLauncher.exe"
set "ROOT_STOP_OUTPUT=%REPO_ROOT%\CloseOpenClawLauncher.exe"

"%CSC%" ^
  /nologo ^
  /target:winexe ^
  /out:"%OUTPUT%" ^
  /reference:System.dll ^
  /reference:System.Windows.Forms.dll ^
  /reference:System.Drawing.dll ^
  "%SCRIPT_DIR%OpenClawLauncher.cs"

if errorlevel 1 exit /b 1

copy /Y "%OUTPUT%" "%ROOT_OUTPUT%" >nul
if errorlevel 1 exit /b 1

"%CSC%" ^
  /nologo ^
  /target:winexe ^
  /out:"%STOP_OUTPUT%" ^
  /reference:System.dll ^
  /reference:System.Windows.Forms.dll ^
  /reference:System.Drawing.dll ^
  "%SCRIPT_DIR%CloseOpenClawLauncher.cs"

if errorlevel 1 exit /b 1

copy /Y "%STOP_OUTPUT%" "%ROOT_STOP_OUTPUT%" >nul
if errorlevel 1 exit /b 1

echo Built: %OUTPUT%
echo Copied: %ROOT_OUTPUT%
echo Built: %STOP_OUTPUT%
echo Copied: %ROOT_STOP_OUTPUT%
