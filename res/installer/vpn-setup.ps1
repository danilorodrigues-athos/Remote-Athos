param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Tailscale', 'Radmin')]
    [string]$Vendor
)

# Optional VPN installer used by NO-Installer.iss. It downloads only from the
# vendor's official URL and verifies both the pinned SHA-256 and Authenticode
# signature before running the silent installer.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$log = Join-Path $env:TEMP 'NO-vpn-install.log'

function Write-Log([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Vendor, $Message
    Add-Content -Path $log -Value $line -Encoding UTF8
}

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'O instalador precisa ser executado como administrador.'
    }
}

function Get-VerifiedDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Sha256,
        [string]$Publisher
    )

    Write-Log "Baixando $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 300

    $actualHash = (Get-FileHash -Path $Destination -Algorithm SHA256).Hash
    if ($actualHash.ToUpperInvariant() -ne $Sha256.ToUpperInvariant()) {
        throw "Hash SHA-256 invalido. Esperado: $Sha256. Obtido: $actualHash"
    }

    $signature = Get-AuthenticodeSignature -FilePath $Destination
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate) {
        throw "Assinatura Authenticode invalida: $($signature.Status)"
    }
    if ($signature.SignerCertificate.Subject -notlike "*$Publisher*") {
        throw "Editor inesperado: $($signature.SignerCertificate.Subject)"
    }

    Write-Log 'Hash e assinatura verificados.'
}

try {
    Assert-Admin
    $workDir = Join-Path $env:TEMP 'NO-vpn-setup'
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null

    switch ($Vendor) {
        'Tailscale' {
            $installer = Join-Path $workDir 'tailscale-setup-1.104.5-amd64.msi'
            Get-VerifiedDownload `
                -Url 'https://pkgs.tailscale.com/stable/tailscale-setup-1.104.5-amd64.msi' `
                -Destination $installer `
                -Sha256 '3C41318C83C5D95D0B017B1BAA08BA7C99FD5334166122BBB1931E55AF99839C' `
                -Publisher 'Tailscale Inc.'

            $installLog = Join-Path $workDir 'tailscale-install.log'
            $installArgs = @(
                '/i', "`"$installer`"", '/quiet', '/norestart',
                'TS_NOLAUNCH=1', '/L*v', "`"$installLog`""
            )
            $process = Start-Process `
                -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') `
                -ArgumentList $installArgs -Wait -PassThru
            if ($process.ExitCode -notin @(0, 3010)) {
                throw "msiexec retornou $($process.ExitCode). Log: $installLog"
            }
            if ($process.ExitCode -eq 3010) {
                Write-Log 'Reinicializacao recomendada pelo Windows Installer.'
            }
        }
        'Radmin' {
            $installer = Join-Path $workDir 'Radmin_VPN_2.1.4951.1.exe'
            Get-VerifiedDownload `
                -Url 'https://download.radmin-vpn.com/download/files/Radmin_VPN_2.1.4951.1.exe' `
                -Destination $installer `
                -Sha256 'E16711E2E3E59F6603F51F437197215B1914A3D8316E1F633260178B959921F7' `
                -Publisher 'Famatech Corp.'

            $installLog = Join-Path $workDir 'radmin-install.log'
            $installArgs = @(
                '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
                "/LOG=`"$installLog`""
            )
            $process = Start-Process -FilePath $installer -ArgumentList $installArgs -Wait -PassThru
            if ($process.ExitCode -notin @(0, 3010)) {
                throw "Radmin VPN retornou $($process.ExitCode). Log: $installLog"
            }
            if ($process.ExitCode -eq 3010) {
                Write-Log 'Reinicializacao recomendada pelo instalador do Radmin.'
            }
        }
    }

    Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue
    Write-Log 'Instalacao concluida.'
    exit 0
} catch {
    Write-Log "FALHA: $($_.Exception.Message)"
    exit 1
}

