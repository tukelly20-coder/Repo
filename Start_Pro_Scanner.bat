@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "PYTHON_EXE=%ROOT_DIR%folderscaner\.venv\Scripts\python.exe"

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
