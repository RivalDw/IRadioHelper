@echo off
title Radio Stream Launcher

echo Starting Icecast...
start "Icecast" cmd /k "cd /d "C:\Program Files (x86)\Icecast" && icecast.bat -c icecast.xml"

echo Waiting for Icecast to initialize...
timeout /t 7 >nul

echo Starting Liquidsoap...
start "Liquidsoap" cmd /k "cd /d "C:\Downloads\liquidsoap-2.4.0-win64" && liquidsoap.exe radio.liq"

echo.
echo Both services should be running now in separate windows.
echo Check that:
echo 1. Icecast shows no errors
echo 2. Liquidsoap is playing music
echo.
echo Press any key to close this launcher...
pause >nul