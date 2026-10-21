$ErrorActionPreference = 'Stop'
$app = 'NO'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$dst = 'C:\Program Files\NO'
$exe = "$dst\NO.exe"

Write-Host "Instalando $app..." -ForegroundColor Cyan

Get-Process NO, rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Force -Path $dst | Out-Null }
$skip = @('Instalar-NO.ps1', 'Desinstalar-NO.ps1')
Get-ChildItem $src -Force | Where-Object { $_.Name -notin $skip } | ForEach-Object {
  Copy-Item $_.FullName -Destination $dst -Recurse -Force
}
Write-Host '  Arquivos copiados.'

Write-Host '  Criando regras de firewall...'
foreach ($proto in @('TCP', 'UDP')) {
  $name = "NO 21118 $proto"
  Remove-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol $proto -LocalPort 21118 -Profile Any -ErrorAction SilentlyContinue | Out-Null
}

Write-Host '  Criando atalhos...'
$shell = New-Object -ComObject WScript.Shell
foreach ($lnk in @("$env:PUBLIC\Desktop\NO.lnk", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NO.lnk")) {
  $shortcut = $shell.CreateShortcut($lnk)
  $shortcut.TargetPath = $exe
  $shortcut.WorkingDirectory = $dst
  $shortcut.Save()
}

Write-Host '  Instalando servico...'
$process = Start-Process -FilePath $exe -ArgumentList '--install-service' -PassThru -WindowStyle Hidden -Wait
Write-Host "  Servico: exit $($process.ExitCode)"

Write-Host ''
Write-Host '  Pronto. Abra o NO pelo atalho da area de trabalho.' -ForegroundColor Green
Write-Host '  Na tela inicial, confira o servico e o diagnostico de firewall.'
Write-Host ''
Start-Sleep -Seconds 3
