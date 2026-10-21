$ErrorActionPreference = 'Stop'
$app = 'NO'
$dst = 'C:\Program Files\NO'
$exe = "$dst\NO.exe"
$firewallRules = @('NO 21118 TCP', 'NO 21118 UDP')

Write-Host "Desinstalando $app..." -ForegroundColor Cyan
Get-Process NO, rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if (Test-Path $exe) {
  Write-Host '  Removendo servico...'
  $process = Start-Process -FilePath $exe -ArgumentList '--uninstall-service' -PassThru -WindowStyle Hidden -Wait
  Write-Host "  Servico: exit $($process.ExitCode)"
}

Write-Host '  Removendo do Program Files...'
for ($i = 0; $i -lt 5; $i++) {
  Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path $dst)) { break }
  Start-Sleep -Seconds 2
}

Write-Host '  Removendo regras de firewall...'
foreach ($rule in $firewallRules) {
  Remove-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
}

Write-Host '  Removendo atalhos...'
Remove-Item "$env:PUBLIC\Desktop\NO.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NO.lnk" -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '  NO removido. Configuracoes e catalogo foram mantidos em %APPDATA%\NO.' -ForegroundColor Green
Start-Sleep -Seconds 3
