@echo off
setlocal EnableExtensions
title Stratego New Automated Tests

for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
set "GODOT_EXE="

if exist "C:\situation-room\Godot_v4.3-stable_win64_console.exe" set "GODOT_EXE=C:\situation-room\Godot_v4.3-stable_win64_console.exe"
if not defined GODOT_EXE (
    for %%G in ("%PROJECT_DIR%\Godot_console.exe" "%PROJECT_DIR%\Godot_v4.3-stable_win64_console.exe" "%PROJECT_DIR%\Godot_v4.4-stable_win64_console.exe" "%PROJECT_DIR%\Godot_v4.5-stable_win64_console.exe") do (
        if exist "%%~G" set "GODOT_EXE=%%~G"
    )
)
if not defined GODOT_EXE (
    for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
if not defined GODOT_EXE (
    for /f "delims=" %%G in ('where godot4.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
if not defined GODOT_EXE (
    echo Stratego could not find Godot 4.
    pause
    exit /b 1
)

rem Build Godot's per-project script-class index on a fresh checkout.
"%GODOT_EXE%" --headless --editor --path "%PROJECT_DIR%" --quit-after 2 >nul
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --script res://tests/test_runner.gd
set "TEST_EXIT=%errorlevel%"
echo.
pause
exit /b %TEST_EXIT%
