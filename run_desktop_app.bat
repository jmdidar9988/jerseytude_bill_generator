@echo off
title Jerseytude Bill Generator
cd /d "%~dp0"

echo Starting Jerseytude Bill Generator...

:: Check if server is already responding on port 8080
powershell -Command "try { $r = [System.Net.WebRequest]::Create('http://127.0.0.1:8080'); $r.Timeout = 1500; $res = $r.GetResponse(); $res.Close(); exit 0 } catch { exit 1 }"
if %ERRORLEVEL% NEQ 0 (
    echo Starting local application engine...
    start /b "" cmd /c "flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1"
    
    :: Wait until port 8080 becomes available (up to 30 seconds)
    echo Connecting...
    powershell -Command "$timeout = 30; $start = [DateTime]::Now; while (([DateTime]::Now - $start).TotalSeconds -lt $timeout) { try { $r = [System.Net.WebRequest]::Create('http://127.0.0.1:8080'); $r.Timeout = 1500; $res = $r.GetResponse(); $res.Close(); exit 0 } catch { Start-Sleep -Milliseconds 800 } }; exit 1"
)

:: Launch in native application mode
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --app="http://127.0.0.1:8080"
) else if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --app="http://127.0.0.1:8080"
) else (
    start http://127.0.0.1:8080
)

exit
