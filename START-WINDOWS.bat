@echo off
setlocal EnableExtensions
title PS4 14.02 test server

rem Resolve to this file's own folder, so double-clicking works no matter what
rem the current directory is. %~dp0 always ends in a backslash.
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

if not exist "%HERE%\web\serve.py" goto :missing
if not exist "%HERE%\web\afterglow.js" goto :missing

pushd "%HERE%\web"
if errorlevel 1 goto :missing

rem Find a Python that actually runs. The Microsoft Store alias is a 0-byte
rem reparse point that opens the Store and returns 9009, so "python --version"
rem succeeding is not a test -- importing sys is what proves a real interpreter.
set "PY="
for %%C in (py python python3) do (
  if not defined PY (
    %%C -c "import sys" >nul 2>&1 && set "PY=%%C"
  )
)
if not defined PY goto :nopython

%PY% serve.py %1
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo   The server stopped with an error ^(exit code %RC%^).
  echo   Copy the text above into the Discord thread.
) else (
  echo   Server stopped.
)
echo.
pause
popd
exit /b %RC%

:nopython
echo.
echo   Python is not installed, or it is only the Microsoft Store stub.
echo.
echo   1. Go to https://www.python.org/downloads/windows/
echo   2. Download the latest Python 3 for Windows.
echo   3. On the first installer screen, TICK "Add python.exe to PATH".
echo   4. Install, then close this window and run START-WINDOWS.bat again.
echo.
echo   The version the Microsoft Store offers does not run scripts from a
echo   folder like this one, so please use python.org.
echo.
pause
popd
exit /b 1

:missing
echo.
echo   This file must stay next to the "web" folder.
echo   Extract the WHOLE zip somewhere first ^(right-click, Extract All^),
echo   then run START-WINDOWS.bat from inside the extracted folder.
echo.
pause
exit /b 1
