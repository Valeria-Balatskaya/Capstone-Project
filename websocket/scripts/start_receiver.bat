@echo off
REM Windows batch script to start WebSocket receiver

SET RECEIVER_ID=R1
SET WS_HOST=192.168.1.100
SET WS_PORT=8765
SET POS_X=0
SET POS_Y=0
SET BACKUP_FOLDER=.\backup

echo ==========================================
echo   LoRa WebSocket Receiver - %RECEIVER_ID%
echo ==========================================
echo Server: ws://%WS_HOST%:%WS_PORT%
echo Position: (%POS_X%, %POS_Y%)
echo Backup: %BACKUP_FOLDER%
echo.

python "%~dp0receiver_ws.py" --id %RECEIVER_ID% --ws-host %WS_HOST% --ws-port %WS_PORT% --x %POS_X% --y %POS_Y% --backup %BACKUP_FOLDER%

pause
