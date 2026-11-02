Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  ALARMYA - Publicar a GitHub (en 2 pasos)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PASO 1 de 2: Autorizar tu cuenta de GitHub" -ForegroundColor Yellow
Write-Host "Se va a abrir el navegador. Copia el codigo de abajo, pegalo en" -ForegroundColor White
Write-Host "la pagina del navegador y pulsa 'Continue'." -ForegroundColor White
$env:PAGER = "cat"
& ".\tools\gh\bin\gh.exe" auth login -h github.com -p https -w
if ($LASTEXITCODE -ne 0) { Write-Host "La autorizacion fallo. Intenta de nuevo." -ForegroundColor Red; Pause; exit 1 }

Write-Host ""
Write-Host "PASO 2 de 2: Creando repo AlarmYa y subiendo el proyecto..." -ForegroundColor Yellow
& ".\tools\gh\bin\gh.exe" auth setup-git
git branch -M main
& ".\tools\gh\bin\gh.exe" repo create AlarmYa --public --source . --push
if ($LASTEXITCODE -ne 0) { Write-Host "Hubo un problema creando o subiendo el repo. Mira el error de arriba." -ForegroundColor Red; Pause; exit 1 }

Write-Host ""
Write-Host "LISTO! El proyecto esta en GitHub y esta compilando." -ForegroundColor Green
Write-Host "https://github.com/flamedo1/AlarmYa/actions" -ForegroundColor Green
Pause
