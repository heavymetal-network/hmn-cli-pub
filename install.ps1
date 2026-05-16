$ErrorActionPreference = "Stop"

# HeavyMetal Network CLI installer for Windows
# Usage: irm https://raw.githubusercontent.com/heavymetal-network/hmn-cli-pub/main/install.ps1 | iex
# Version-pinned: $env:HMN_VERSION = "0.1.0"; irm ... | iex

$Repo   = "heavymetal-network/hmn-cli-pub"
$Binary = "hmn.exe"

$Arch = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else {
    Write-Error "Unsupported architecture"; exit 1
}

if ($env:HMN_VERSION) {
    $Version = $env:HMN_VERSION
} else {
    Write-Host "Fetching latest hmn-cli release..."
    $Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $Version = $Release.tag_name -replace '^v', ''
}

if (-not $Version) {
    Write-Error "Could not determine version. Set `$env:HMN_VERSION = 'x.y.z' to override."
    exit 1
}

Write-Host "Installing hmn v$Version (windows/$Arch)..."

$Archive = "hmn_${Version}_windows_${Arch}.zip"
$BaseUrl = "https://github.com/$Repo/releases/download/v$Version"
$TmpDir  = Join-Path $env:TEMP "hmn-install-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    Invoke-WebRequest "$BaseUrl/$Archive" -OutFile "$TmpDir\$Archive"
    Invoke-WebRequest "$BaseUrl/hmn_${Version}_checksums.txt" -OutFile "$TmpDir\checksums.txt"

    $Expected = (Get-Content "$TmpDir\checksums.txt" | Where-Object { $_ -match [regex]::Escape($Archive) }) -split '\s+' | Select-Object -First 1
    $Actual   = (Get-FileHash "$TmpDir\$Archive" -Algorithm SHA256).Hash.ToLower()
    if ($Actual -ne $Expected) { Write-Error "Checksum mismatch — aborting"; exit 1 }

    Expand-Archive "$TmpDir\$Archive" -DestinationPath $TmpDir

    $InstallDir = Join-Path $HOME "bin"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item "$TmpDir\$Binary" "$InstallDir\$Binary" -Force

    $UserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$UserPath;$InstallDir", "User")
        $env:PATH += ";$InstallDir"
        Write-Host "Added $InstallDir to your PATH (restart terminal to take effect)"
    }

    Write-Host ""
    Write-Host "hmn v$Version installed to $InstallDir\$Binary"
    & "$InstallDir\$Binary" --version
} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
