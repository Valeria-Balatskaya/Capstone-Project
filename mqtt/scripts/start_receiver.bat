@echo off
REM Windows batch script to start MQTT receiver
REM Edit these values before running!

SET RECEIVER_ID=R1
SET MQTT_HOST=192.168.1.100
SET SERIAL_PORT=COM3
SET POS_X=0
SET POS_Y=0

echo ==========================================
echo   LoRa MQTT Receiver - %RECEIVER_ID%
echo ==========================================
echo MQTT Host: %MQTT_HOST%
echo Serial Port: %SERIAL_PORT%
echo Position: (%POS_X%, %POS_Y%)
echo.

python "%~dp0receiver_mqtt.py" --id %RECEIVER_ID% --mqtt-host %MQTT_HOST% --serial-port %SERIAL_PORT% --x %POS_X% --y %POS_Y%

pause
