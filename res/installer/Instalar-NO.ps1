$ErrorActionPreference = 'Stop'
$app = 'NO'
$dst = 'C:\Program Files\NO'
$exe = "$dst\NO.exe"
$log = Join-Path $env:TEMP 'NO-install.log'
$scriptPath = $PSCommandPath
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
  Write-Host 'O instalador precisa ser executado como administrador.' -ForegroundColor Yellow
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

$src = $PSScriptRoot
if (-not $src) { $src = Split-Path -Parent $scriptPath }

$transcriptStarted = $false
try {
  Start-Transcript -Path $log -Force | Out-Null
  $transcriptStarted = $true
} catch {
  Write-Host "Nao foi possivel criar o log em $log." -ForegroundColor Yellow
}

try {
  Write-Host "Instalando $app..." -ForegroundColor Cyan
  Write-Host "Origem: $src"
  Write-Host "Destino: $dst"

  Get-Process NO -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2

  $svc = Get-Service -Name NO -ErrorAction SilentlyContinue
  if ($svc) {
    Write-Host '  Parando servico existente...'
    Stop-Service -Name NO -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
  }

  if (-not (Test-Path $dst)) {
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
  }

  $skip = @('Instalar-NO.ps1', 'Instalar-NO.cmd', 'Desinstalar-NO.ps1', 'Desinstalar-NO.cmd')
  Get-ChildItem $src -Force | Where-Object { $_.Name -notin $skip } | ForEach-Object {
    Copy-Item $_.FullName -Destination $dst -Recurse -Force
  }
  if (-not (Test-Path $exe)) { throw "NO.exe nao foi copiado para $dst." }
  Write-Host '  Arquivos copiados.'

  Write-Host '  Criando regras de firewall...'
  foreach ($proto in @('TCP', 'UDP')) {
    $name = "NO 21118 $proto"
    Remove-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol $proto -LocalPort 21118 -Profile Any | Out-Null
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
  if ($process.ExitCode -ne 0) { throw "Falha ao instalar o servico (codigo $($process.ExitCode))." }

  $svc = Get-Service -Name NO -ErrorAction SilentlyContinue
  if (-not $svc) { throw 'Servico NO nao encontrado apos a instalacao.' }
  if ($svc.Status -ne 'Running') {
    Start-Service -Name NO -ErrorAction Stop
    Start-Sleep -Seconds 2
  }
  $svc = Get-Service -Name NO
  Write-Host "  Servico: $($svc.Status)" -ForegroundColor Green

  Write-Host '  Registrando desinstalacao...'
  $uninstallDir = Join-Path $env:ProgramData 'NO'
  New-Item -ItemType Directory -Force -Path $uninstallDir | Out-Null
  Copy-Item (Join-Path $src 'Desinstalar-NO.ps1') (Join-Path $uninstallDir 'Desinstalar-NO.ps1') -Force
  Copy-Item (Join-Path $src 'Desinstalar-NO.cmd') (Join-Path $uninstallDir 'Desinstalar-NO.cmd') -Force
  $uninstallCmd = Join-Path $uninstallDir 'Desinstalar-NO.cmd'
  $uninstallString = "`"$env:SystemRoot\System32\cmd.exe`" /c `"$uninstallCmd`""
  $version = (Get-Item $exe).VersionInfo.ProductVersion
  if ([string]::IsNullOrWhiteSpace($version)) { $version = '1.5.2' }
  $brand = "N$([char]0x00D3)"
  $uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NO'
  New-Item -Path $uninstallKey -Force | Out-Null
  Set-ItemProperty -Path $uninstallKey -Name DisplayName -Value "$brand - suporte remoto local"
  Set-ItemProperty -Path $uninstallKey -Name DisplayVersion -Value $version
  Set-ItemProperty -Path $uninstallKey -Name Publisher -Value 'Purslane Tech Pte. Ltd.'
  Set-ItemProperty -Path $uninstallKey -Name InstallLocation -Value $dst
  Set-ItemProperty -Path $uninstallKey -Name DisplayIcon -Value "$exe,0"
  Set-ItemProperty -Path $uninstallKey -Name UninstallString -Value $uninstallString
  Set-ItemProperty -Path $uninstallKey -Name InstallDate -Value (Get-Date -Format 'yyyyMMdd')
  New-ItemProperty -Path $uninstallKey -Name NoModify -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name NoRepair -Value 1 -PropertyType DWord -Force | Out-Null
  Write-Host '  Entrada criada em Aplicativos e recursos.'

  Write-Host ''
  Write-Host '  Pronto. Abra o NO pelo atalho da area de trabalho.' -ForegroundColor Green
  Write-Host '  Na tela inicial, confira o servico e o diagnostico de firewall.'
  Write-Host ''
  Write-Host "Log: $log"
} catch {
  Write-Host ''
  Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Log completo: $log" -ForegroundColor Yellow
} finally {
  if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch {} }
  Write-Host ''
  Read-Host 'Pressione Enter para fechar'
}
