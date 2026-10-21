# Instalador do NO
# Copia o aplicativo para Program Files, cria atalhos, libera a porta 21118
# e instala o servico do Windows.

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

$src = Split-Path -Parent $PSCommandPath
$dst = Join-Path $env:ProgramFiles 'NO'
$exe = Join-Path $dst 'NO.exe'

Write-Host ''
Write-Host '  NO - instalacao local' -ForegroundColor Cyan
Write-Host '  ---------------------' -ForegroundColor Cyan
Write-Host "  Destino: $dst"
Write-Host ''

Get-Process NO, rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Force -Path $dst | Out-Null
$skip = @('Instalar-NO.ps1', 'Desinstalar-NO.ps1', 'LEIA-ME-TESTE.md')
Get-ChildItem -Path $src -Force | Where-Object { $skip -notcontains $_.Name } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $dst -Recurse -Force
}

foreach ($protocol in @('TCP', 'UDP')) {
    $rule = "NO 21118 $protocol"
    if (-not (Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol $protocol `
            -LocalPort 21118 -Action Allow -Profile Any | Out-Null
        Write-Host "  Firewall: $rule criada"
    } else {
        Write-Host "  Firewall: $rule ja existe"
    }
}

$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
$publicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
foreach ($folder in @($publicDesktop, $startMenu)) {
    $shortcut = $shell.CreateShortcut((Join-Path $folder 'NO.lnk'))
    $shortcut.TargetPath = $exe
    $shortcut.WorkingDirectory = $dst
    $shortcut.Description = 'NO - acesso remoto local'
    $shortcut.Save()
}
Write-Host '  Atalhos criados (area de trabalho e menu Iniciar)'

if (Test-Path $exe) {
    Write-Host '  Instalando o servico do Windows...'
    $process = Start-Process -FilePath $exe -ArgumentList '--install-service' `
        -WorkingDirectory $dst -PassThru -WindowStyle Hidden
    $process | Wait-Process -Timeout 45 -ErrorAction SilentlyContinue
    Write-Host '  Servico: solicitado (confirme na tela inicial do NO)'
}

Write-Host ''
Write-Host '  Pronto. Abra o NO pelo atalho da area de trabalho.' -ForegroundColor Green
Write-Host '  Na tela inicial, confira o servico e o diagnostico de firewall.'
Write-Host ''
Start-Sleep -Seconds 3
