@echo off
setlocal

rem Resolve the folder without a trailing backslash. A trailing backslash can
rem escape the closing quote when Windows passes the path to an application.
for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
set "GODOT_EXE="

rem Use the Godot installation already available on this computer.
if exist "C:\situation-room\Godot_v4.3-stable_win64.exe" set "GODOT_EXE=C:\situation-room\Godot_v4.3-stable_win64.exe"

rem Also support a portable Godot executable placed beside this launcher.
if not defined GODOT_EXE (
    for %%G in ("%PROJECT_DIR%\Godot.exe" "%PROJECT_DIR%\Godot_v4.3-stable_win64.exe" "%PROJECT_DIR%\Godot_v4.4-stable_win64.exe" "%PROJECT_DIR%\Godot_v4.5-stable_win64.exe") do (
        if exist "%%~G" set "GODOT_EXE=%%~G"
    )
)

rem Finally, look for Godot on the system PATH.
if not defined GODOT_EXE (
    for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
if not defined GODOT_EXE (
    for /f "delims=" %%G in ('where godot4.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)

if not defined GODOT_EXE (
    echo.
    echo Stratego could not find Godot 4.
    echo Install Godot 4, or place Godot.exe in this folder, then try again.
    echo.
    pause
    exit /b 1
)

start "" "%GODOT_EXE%" --path "%PROJECT_DIR%" %*
exit /b 0
