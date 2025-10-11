@echo off
REM Windows Batch Wrapper for AWS Deployment
REM This script automatically runs the interactive deployment in Git Bash

echo ============================================
echo License Plate Recognition - AWS Deployment
echo ============================================
echo.

REM Try to find Git Bash in common locations
set "GIT_BASH="

REM Check if bash.exe is in PATH
where bash.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('where bash.exe') do (
        set "BASH_PATH=%%i"
        echo Found bash at: !BASH_PATH!
        REM Check if it's Git Bash (not WSL)
        echo !BASH_PATH! | findstr /i /c:"Git" >nul
        if !ERRORLEVEL! EQU 0 (
            set "GIT_BASH=%%i"
            goto :found_git_bash
        )
    )
)

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

REM If we get here, Git Bash was not found
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
echo [INFO] Starting interactive deployment...
echo.

REM Run the interactive script in Git Bash
"%GIT_BASH%" "%~dp0deploy-interactive.sh"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Deployment failed or was cancelled.
    pause
    exit /b 1
)

echo.
echo [INFO] Deployment completed successfully!
pause

