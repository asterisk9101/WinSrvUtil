@echo off
pushd %~dp0
powershell -ExecutionPolicy RemoteSigned -File %*
set /a rc=%ERRORLEVEL%
popd
exit /b %rc%
