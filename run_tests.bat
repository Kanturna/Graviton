@echo off
"D:\Programme\Godot\Godot.exe" --path "%~dp0" --headless --script res://src/tests/test_runner.gd --quit
exit /b %ERRORLEVEL%
