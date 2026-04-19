@echo off
setlocal
pushd "%~dp0" >nul
"D:\Programme\Godot\godot_console.exe" --path . --headless --script res://src/tests/test_runner.gd --quit
set "EXIT_CODE=%ERRORLEVEL%"
popd >nul
endlocal & exit /b %EXIT_CODE%
