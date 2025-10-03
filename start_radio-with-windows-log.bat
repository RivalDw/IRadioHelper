@echo off
title Radio Stream Launcher

REM --- Настройки ---
set ICECAST_DIR=C:\Program Files (x86)\Icecast
set ICECAST_CONFIG=icecast.xml
set ICECAST_PORT=8000
set LIQUIDSOAP_DIR=C:\Users\RaDw\Downloads\liquidsoap-2.4.0-win64
set LIQUIDSOAP_SCRIPT=radio.liq

REM --- Запуск Icecast ---
echo Starting Icecast...
start "Icecast" cmd /k "cd /d "%ICECAST_DIR%" && icecast.bat -c %ICECAST_CONFIG%"

REM --- Проверка, что Icecast запущен ---
echo Waiting for Icecast to initialize...
:CHECK_ICECAST
timeout /t 3 >nul
 
curl --silent --head http://localhost:%ICECAST_PORT%/ >nul 2>&1
if %errorlevel% neq 0 (
    echo Icecast not ready yet, retrying...
    goto CHECK_ICECAST
)
echo Icecast is running!

REM --- Запуск Liquidsoap ---
echo Starting Liquidsoap...
start "Liquidsoap" cmd /k "cd /d "%LIQUIDSOAP_DIR%" && liquidsoap.exe %LIQUIDSOAP_SCRIPT%"

echo.
echo Both services should be running now in separate windows.
echo Check that:
echo 1. Icecast shows no errors
echo 2. Liquidsoap is playing music
echo.
echo Press any key to close this launcher...
pause >nul
