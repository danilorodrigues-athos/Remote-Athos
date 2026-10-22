param(
    [Parameter(Mandatory = $true)][string]$PayloadDir,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$PayloadDir = [IO.Path]::GetFullPath($PayloadDir).TrimEnd('\')
$OutputDir = [IO.Path]::GetFullPath($OutputDir).TrimEnd('\')
$appExe = Join-Path $PayloadDir 'NO.exe'
if (-not (Test-Path $appExe)) {
    throw "NO.exe não encontrado em $PayloadDir"
}

$programFiles = [Environment]::GetFolderPath('ProgramFiles')
$programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
$candidates = @(
    (Join-Path $programFiles 'Inno Setup 6\ISCC.exe'),
    (Join-Path $programFilesX86 'Inno Setup 6\ISCC.exe')
) | Where-Object { $_ -and (Test-Path $_) }

$iscc = $candidates | Select-Object -First 1
if (-not $iscc) {
    $iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
}
if (-not $iscc) {
    throw 'ISCC.exe não encontrado. Instale o Inno Setup 6 no runner.'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$version = (Get-Item $appExe).VersionInfo.FileVersion
if ([string]::IsNullOrWhiteSpace($version)) {
    $version = '1.5.1+0'
}
$baseVersion = ($version -split '\+')[0]
$buildNumber = if ($version -match '\+(\d+)') { $Matches[1] } else { '0' }
if ($baseVersion -notmatch '^\d+\.\d+\.\d+$') {
    $baseVersion = '1.5.1'
}
if ($buildNumber -notmatch '^\d+$') {
    $buildNumber = '0'
}

& $iscc `
    "/DPayloadDir=$PayloadDir" `
    "/DOutputDir=$OutputDir" `
    "/DMyAppVersion=$baseVersion" `
    "/DMyAppBuild=$buildNumber" `
    (Join-Path $PSScriptRoot 'NO-Installer.iss')

if ($LASTEXITCODE -ne 0) {
    throw "ISCC falhou com o código $LASTEXITCODE."
}

$installer = Join-Path $OutputDir 'Instalar-NO.exe'
if (-not (Test-Path $installer)) {
    throw "Instalador não encontrado em $installer"
}

Get-Item $installer | Select-Object FullName, Length, LastWriteTime | Format-List
Get-FileHash $installer -Algorithm SHA256 | Format-List
