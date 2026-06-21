$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$apiHost = if ($env:API_HOST) { $env:API_HOST } else { '192.168.1.15' }

function Start-HiddenService {
    param(
        [string]$Name,
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string]$LogName
    )

    $logDirectory = Join-Path $root '.service-logs'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDirectory "$LogName.log") `
        -RedirectStandardError (Join-Path $logDirectory "$LogName.error.log") `
        -PassThru

    Write-Host "$Name berjalan dengan PID $($process.Id)"
}

Start-HiddenService `
    -Name 'Bank Sampah API' `
    -FilePath 'node' `
    -Arguments @('app.js') `
    -WorkingDirectory (Join-Path $root 'bank_sampah_api') `
    -LogName 'bank-api'

Start-HiddenService `
    -Name 'Face Recognition API' `
    -FilePath (Join-Path $root 'face-api\.venv\Scripts\python.exe') `
    -Arguments @('run.py') `
    -WorkingDirectory (Join-Path $root 'face-api') `
    -LogName 'face-api'

Start-HiddenService `
    -Name 'Chatbot API' `
    -FilePath 'C:\Users\daven\anaconda3\python.exe' `
    -Arguments @('-m', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', '8001') `
    -WorkingDirectory (Join-Path $root 'nlp-api') `
    -LogName 'nlp-api'

Write-Host ''
Write-Host 'Health endpoints:'
Write-Host '  http://127.0.0.1:3000/health'
Write-Host '  http://127.0.0.1:5000/health'
Write-Host "  http://$apiHost`:3000/nlp/health (proxy untuk NLP lokal)"
Write-Host "  http://$apiHost`:8001/health (NLP langsung - untuk NLP_DIRECT_URL)"
