@echo off
REM Complete Windows Deployment Wrapper
REM Finds Git Bash and runs the complete deployment script

setlocal enabledelayedexpansion

echo ============================================
echo License Plate Recognition - Complete Setup
echo ============================================
echo.

REM Try to find Git Bash
set "GIT_BASH="

REM Check common Git installation paths
if exist "C:\Program Files\Git\bin\bash.exe" (
    set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"
    goto :found_git_bash
)

if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
    goto :found_git_bash
)

if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    set "GIT_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
    goto :found_git_bash
)

if exist "%PROGRAMFILES%\Git\bin\bash.exe" (
    set "GIT_BASH=%PROGRAMFILES%\Git\bin\bash.exe"
    goto :found_git_bash
)

REM Git Bash not found
echo [ERROR] Git Bash not found!
echo.
echo Please install Git for Windows from:
echo https://git-scm.com/download/win
echo.
echo After installation, run this script again.
echo.
pause
exit /b 1

:found_git_bash
echo [INFO] Found Git Bash: %GIT_BASH%
echo [INFO] Starting complete deployment setup...
echo.

REM Run the complete deployment script
"%GIT_BASH%" "%~dp0deploy-complete.sh"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Deployment failed or was cancelled.
    pause
    exit /b 1
)

echo.
echo [INFO] Deployment completed successfully!
pause


