@echo off
setlocal

set "SCRIPT=.\scripts\windows\build_android_bywin.ps1"

if not "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
    goto end
)

:menu
cls
echo ================================================
echo   Macro Deck Client - Android Build Tool
echo ================================================
echo.
echo   [1] Check build environment
echo   [2] Build release APK / AAB
echo   [3] Publish to GitHub Release
echo   [4] Publish to Gitee Release
echo   [5] Show help
echo   [0] Exit
echo.
set /p "choice=Select an option: "

if "%choice%"=="1" goto check
if "%choice%"=="2" goto build
if "%choice%"=="3" goto publish_github
if "%choice%"=="4" goto publish_gitee
if "%choice%"=="5" goto help
if "%choice%"=="0" goto end
goto menu

:check
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Check
goto done

:build
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Build
goto done

:publish_github
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Publish -Platform github
goto done

:publish_gitee
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Publish -Platform gitee
goto done

:help
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Help
goto done

:done
echo.
pause
goto menu

:end
endlocal
