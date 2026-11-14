@echo off
REM Recalcula los resultados de los dashboards (BQ tipo 4 y abandono) y los
REM guarda en Firestore (analytics_results). La app los muestra al instante.
REM Uso: doble clic en este archivo, o desde PowerShell:  analytics\actualizar_dashboards.cmd

REM Node.js (por si la terminal no lo tiene en el PATH)
set "PATH=%PATH%;C:\Program Files\nodejs"

REM Llave de la cuenta de servicio (NO la copies dentro del proyecto)
set "GOOGLE_APPLICATION_CREDENTIALS=C:\Users\laura\Downloads\moviles-9132d-firebase-adminsdk-fbsvc-4012ff0b6f.json"

REM Carpeta espoti (la carpeta padre de este archivo)
cd /d "%~dp0.."

REM Si falta la libreria firebase-admin en esta carpeta, se instala una vez.
if not exist "node_modules\firebase-admin" (
  echo Instalando firebase-admin...
  if not exist "package.json" call npm.cmd init -y
  call npm.cmd install firebase-admin
)

echo === Codigos de amigo (directorio user_codes) ===
node analytics\publish_user_codes.js
echo.
echo === BQ tipo 4: picos de reuniones ===
node analytics\meeting_peak_windows.js
echo.
echo === BQ abandono de planificacion ===
node analytics\planning_abandonment.js
echo.
pause
