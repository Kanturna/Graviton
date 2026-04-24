@echo off
setlocal
pushd "%~dp0" >nul
if "%GODOT_BIN%"=="" (
    set "GODOT_BIN=godot_console.exe"
)
"%GODOT_BIN%" --path . --headless --script res://src/tests/test_runner.gd --quit
set "EXIT_CODE=%ERRORLEVEL%"
popd >nul
endlocal & exit /b %EXIT_CODE%
