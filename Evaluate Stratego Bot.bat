@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Stratego Champion Evaluation

for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
set "GODOT_EXE="
if exist "C:\situation-room\Godot_v4.3-stable_win64_console.exe" set "GODOT_EXE=C:\situation-room\Godot_v4.3-stable_win64_console.exe"
if not defined GODOT_EXE (
    for %%G in ("%PROJECT_DIR%\Godot_console.exe" "%PROJECT_DIR%\Godot_v4.3-stable_win64_console.exe" "%PROJECT_DIR%\Godot_v4.4-stable_win64_console.exe" "%PROJECT_DIR%\Godot_v4.5-stable_win64_console.exe") do (
        if exist "%%~G" set "GODOT_EXE=%%~G"
    )
)
if not defined GODOT_EXE (
    echo Stratego could not find Godot 4.
    pause
    exit /b 1
)

echo.
echo STRATEGO CHAMPION EVALUATION
echo ============================
echo This does not train or modify either bot.
echo.
set /p "EVALUATION_GAMES=Number of matches [200]: "
if not defined EVALUATION_GAMES set "EVALUATION_GAMES=200"
set "INVALID_GAMES="
for /f "delims=0123456789" %%A in ("!EVALUATION_GAMES!") do set "INVALID_GAMES=1"
if defined INVALID_GAMES (
    echo Please enter a whole number, such as 200.
    pause
    exit /b 1
)

echo.
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --script res://training/evaluate_models.gd -- --matches=!EVALUATION_GAMES!
set "EVALUATION_EXIT=!errorlevel!"
echo.
pause
exit /b !EVALUATION_EXIT!

