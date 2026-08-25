@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "PYTHON_EXE=%ROOT_DIR%folderscaner\.venv\Scripts\python.exe"

echo Restarting Pro Scanner services...
echo Stopping old Propack/Folder Scanner processes if any...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'SilentlyContinue';" ^
    "$currentPid = $PID;" ^
    "$ports = @(8001, 12345, 18001);" ^
    "$portPids = @(Get-NetTCPConnection -State Listen -LocalPort $ports | Select-Object -ExpandProperty OwningProcess);" ^
    "$cmdPids = @(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $currentPid -and $_.CommandLine -and ($_.CommandLine -like '*Start_Pro_Scanner.py*' -or $_.CommandLine -like '*propack*propack*server.py*' -or $_.CommandLine -like '*uvicorn*app.main:app*' -or ($_.CommandLine -like '*folderscaner*frontend*' -and $_.CommandLine -like '*npm*run*build*')) } | Select-Object -ExpandProperty ProcessId);" ^
    "$pids = @($portPids + $cmdPids) | Where-Object { $_ -and $_ -ne $currentPid } | Sort-Object -Unique;" ^
    "foreach ($id in $pids) { Write-Host ('Stopping old process tree PID ' + $id); & taskkill.exe /T /F /PID $id | Out-Null }"
timeout /t 1 /nobreak >nul
echo Cleanup complete.
echo.

if not exist "%PYTHON_EXE%" (
    echo Python virtual environment not found:
    echo   %PYTHON_EXE%
    echo.
    echo Create it first with:
    echo   C:\Users\Kelly\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m venv folderscaner\.venv
    pause
    exit /b 1
)

"%PYTHON_EXE%" "%ROOT_DIR%Start_Pro_Scanner.py" %*
