& {
$ErrorActionPreference = "Stop"

# HeavyMetal Network CLI installer for Windows
# Usage: irm https://raw.githubusercontent.com/heavymetal-network/hmn-cli-pub/main/install.ps1 | iex
# Version-pinned: $env:HMN_VERSION = "0.1.0"; irm ... | iex

$Repo   = "heavymetal-network/hmn-cli-pub"
$Binary = "hmn.exe"

$Arch = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else {
    throw "Unsupported architecture: a 64-bit Windows system is required."
}

if ($env:HMN_VERSION) {
    $Version = $env:HMN_VERSION
} else {
    Write-Host "Fetching latest hmn-cli release..."
    $Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $Version = $Release.tag_name -replace '^v', ''
}

$Version = $Version -replace '^v', ''
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$') {
    throw "Invalid version. Set `$env:HMN_VERSION to a release version such as 0.17.77."
}

Write-Host "Installing hmn v$Version (windows/$Arch)..."

$Archive = "hmn_${Version}_windows_${Arch}.zip"
$BaseUrl = "https://github.com/$Repo/releases/download/v$Version"
$TmpDir  = Join-Path $env:TEMP "hmn-install-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    Invoke-WebRequest "$BaseUrl/$Archive" -UseBasicParsing -OutFile "$TmpDir\$Archive"
    Invoke-WebRequest "$BaseUrl/hmn_${Version}_checksums.txt" -UseBasicParsing -OutFile "$TmpDir\checksums.txt"

    $ChecksumLines = @(Get-Content "$TmpDir\checksums.txt" | Where-Object {
        $_ -cmatch ('^[0-9a-fA-F]{64}\s+\*?' + [regex]::Escape($Archive) + '$')
    })
    if ($ChecksumLines.Count -ne 1) {
        throw "Expected exactly one valid SHA-256 checksum for $Archive."
    }
    $Expected = ($ChecksumLines[0] -split '\s+')[0]
    $Actual = (Get-FileHash "$TmpDir\$Archive" -Algorithm SHA256).Hash
    if ($Actual -ne $Expected) { throw "Checksum mismatch - aborting." }

    Expand-Archive "$TmpDir\$Archive" -DestinationPath $TmpDir

    $InstallDir = Join-Path $HOME "bin"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item "$TmpDir\$Binary" "$InstallDir\$Binary" -Force

    $UserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if (($UserPath -split ';') -notcontains $InstallDir) {
        [System.Environment]::SetEnvironmentVariable("PATH", "$UserPath;$InstallDir", "User")
        Write-Host "Added $InstallDir to your PATH (restart terminal to take effect)"
    }

    if (($env:PATH -split ';') -notcontains $InstallDir) {
        $env:PATH += ";$InstallDir"
    }

    Write-Host ""
    Write-Host "hmn v$Version installed to $InstallDir\$Binary"
    & "$InstallDir\$Binary" --version
    if ($LASTEXITCODE -ne 0) { throw "hmn was copied, but could not run. Check platform compatibility." }
    Write-Host "Next: run 'hmn setup' to get started."
} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
}
