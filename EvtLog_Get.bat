@echo off
pushd %~dp0
powershell -ExecutionPolicy RemoteSigned -File %~dpn0.ps1 %*
set rc=%ERRORLEVEL%
popd
exit /b %rc%