$ErrorActionPreference = 'Stop'
$app = 'NO'
$dst = 'C:\Program Files\NO'
$exe = "$dst\NO.exe"
$firewallRules = @('NO 21118 TCP', 'NO 21118 UDP')
$uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NO'
$uninstallDir = Join-Path $env:ProgramData 'NO'
$log = Join-Path $env:TEMP 'NO-uninstall.log'
$scriptPath = $PSCommandPath
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
  Write-Host 'O desinstalador precisa ser executado como administrador.' -ForegroundColor Yellow
  Write-Host 'Abrindo a solicitacao do UAC...'
  $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $elevatedArgs = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$scriptPath`""
  try {
    Start-Process -FilePath $psExe -Verb RunAs -ArgumentList $elevatedArgs | Out-Null
  } catch {
    Write-Host "Nao foi possivel abrir o UAC: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Pressione Enter para sair'
  }
  exit
}

$transcriptStarted = $false
try {
  Start-Transcript -Path $log -Force | Out-Null
  $transcriptStarted = $true
} catch {
  Write-Host "Nao foi possivel criar o log em $log." -ForegroundColor Yellow
}

try {
  Write-Host "Desinstalando $app..." -ForegroundColor Cyan

  Get-Process NO -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2

  $svc = Get-Service -Name NO -ErrorAction SilentlyContinue
  if ($svc) {
    Write-Host '  Removendo servico...'
    if (Test-Path $exe) {
      $process = Start-Process -FilePath $exe -ArgumentList '--uninstall-service' -PassThru -WindowStyle Hidden -Wait
      Write-Host "  Servico: exit $($process.ExitCode)"
    } else {
      sc.exe stop NO | Out-Null
      sc.exe delete NO | Out-Null
      Start-Sleep -Seconds 2
    }
  }

  Write-Host '  Removendo do Program Files...'
  for ($i = 0; $i -lt 5; $i++) {
    Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $dst)) { break }
    Start-Sleep -Seconds 2
  }
  if (Test-Path $dst) { throw "Nao foi possivel remover $dst. Feche o NO e tente novamente." }

  Write-Host '  Removendo regras de firewall...'
  foreach ($rule in $firewallRules) {
    Remove-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
  }

  Write-Host '  Removendo atalhos...'
  Remove-Item "$env:PUBLIC\Desktop\NO.lnk" -Force -ErrorAction SilentlyContinue
  Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NO.lnk" -Force -ErrorAction SilentlyContinue

  Write-Host '  Removendo entrada de Aplicativos e Recursos...'
  Remove-Item $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue

  Write-Host ''
  Write-Host '  NO removido. Configuracoes e catalogo foram mantidos em %APPDATA%\NO.' -ForegroundColor Green
  Write-Host "Log: $log"
} catch {
  Write-Host ''
  Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Log completo: $log" -ForegroundColor Yellow
} finally {
  if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch {} }
  Write-Host ''
  Read-Host 'Pressione Enter para fechar'
  if (Test-Path $uninstallDir) {
    try {
      $cleanup = "ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"$uninstallDir`""
      Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', $cleanup -WindowStyle Hidden -WorkingDirectory $env:SystemRoot
    } catch {}
  }
}
