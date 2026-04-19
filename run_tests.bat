@echo off
"D:\Programme\Godot\godot_console.exe" --path "%~dp0" --headless --script res://src/tests/test_runner.gd --quit
exit /b %ERRORLEVEL%
