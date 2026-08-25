@echo off
setlocal

set "ROOT_DIR=%~dp0"
wscript.exe "%ROOT_DIR%Start_Pro_Scanner_Hidden.vbs" %*
