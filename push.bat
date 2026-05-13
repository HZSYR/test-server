@echo off
cd /d "%~dp0"
echo ========================================
echo   PUSH TO GITHUB - SCRT SERVER
echo ========================================
echo.

git add .
git commit -m "update"
git push origin main

echo.
echo ========================================
echo   SELESAI!
echo ========================================
pause
