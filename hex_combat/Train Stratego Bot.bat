@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Stratego Bot Training

for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
set "GODOT_EXE="

rem Prefer the console build so training progress remains visible.
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
    echo.
    echo Stratego could not find Godot 4.
    echo Place a Godot executable in this folder, then try again.
    echo.
    pause
    exit /b 1
)

echo.
echo STRATEGO BOT TRAINING
echo =====================
echo More matches take longer but give the bot more chances to improve.
echo A good training session is 512 matches, which tests 64 challengers.
echo The best contender must then beat the reigning bot in a title match.
echo.
set /p "TRAINING_GAMES=Number of matches [512]: "
if not defined TRAINING_GAMES set "TRAINING_GAMES=512"

set "INVALID_GAMES="
for /f "delims=0123456789" %%A in ("!TRAINING_GAMES!") do set "INVALID_GAMES=1"
if defined INVALID_GAMES (
    echo.
    echo Please enter a whole number, such as 512.
    echo.
    pause
    exit /b 1
)

echo.
echo Training for !TRAINING_GAMES! matches...
echo.
"%GODOT_EXE%" --headless --editor --path "%PROJECT_DIR%" --quit-after 2 >nul
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --script res://training/self_play.gd -- --games=!TRAINING_GAMES!

set "TRAINING_EXIT=!errorlevel!"

if not "!TRAINING_EXIT!"=="0" (
    echo.
    echo Training stopped because of an error.
) else (
    echo.
    echo Training finished successfully.
    echo Restart Stratego to play against the updated bot.
)
echo.
pause
exit /b !TRAINING_EXIT!
