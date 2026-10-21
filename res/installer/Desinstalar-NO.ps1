# Desinstalador do NO
# Remove o servico, as regras de firewall, os atalhos e a pasta do programa.

$ErrorActionPreference = 'Stop'

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    )
    exit
}

$dst = Join-Path $env:ProgramFiles 'NO'
$exe = Join-Path $dst 'NO.exe'

Write-Host ''
Write-Host '  NO - desinstalacao' -ForegroundColor Cyan
Write-Host '  ------------------' -ForegroundColor Cyan
Write-Host ''

Get-Process NO, rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

if (Test-Path $exe) {
    Write-Host '  Removendo o servico do Windows...'
    $process = Start-Process -FilePath $exe -ArgumentList '--uninstall-service' `
        -WorkingDirectory $dst -PassThru -WindowStyle Hidden
    $process | Wait-Process -Timeout 45 -ErrorAction SilentlyContinue
}

foreach ($protocol in @('TCP', 'UDP')) {
    Remove-NetFirewallRule -DisplayName "NO 21118 $protocol" -ErrorAction SilentlyContinue
}
Write-Host '  Regras de firewall removidas'

$startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
foreach ($shortcut in @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'NO.lnk'),
    (Join-Path $startMenu 'NO.lnk')
)) {
    Remove-Item -Path $shortcut -Force -ErrorAction SilentlyContinue
}
Write-Host '  Atalhos removidos'

if (Test-Path $dst) {
    Remove-Item -Path $dst -Recurse -Force
    Write-Host "  Pasta removida: $dst"
}

$answer = Read-Host 'Remover tambem os dados (catalogo, senhas e configuracoes)? [s/N]'
if ($answer -match '^[sS]') {
    $data = Join-Path $env:APPDATA 'NO'
    if (Test-Path $data) {
        Remove-Item -Path $data -Recurse -Force
        Write-Host "  Dados removidos: $data"
    }
}

Write-Host ''
Write-Host '  NO removido.' -ForegroundColor Green
Read-Host 'Pressione Enter para fechar'
