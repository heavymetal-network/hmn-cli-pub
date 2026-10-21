# HeavyMetal Network CLI

`hmn` is the command-line client for [HeavyMetal Network](https://heavymetal.network). Use it to connect your AI coding tools to the network, check your connection, and manage a machine that contributes compute.

This repo hosts the CLI downloads and installation scripts for macOS, Linux, and Windows.

## Install

### macOS

With [Homebrew](https://brew.sh):

```sh
brew install heavymetal-network/tap/hmn
```

Or use the installer, which installs Homebrew first if needed:

```sh
curl -fsSL https://api.heavymetal.network/install.sh | sh
```

Follow any PATH instructions printed at the end. Both Apple Silicon and Intel Macs are supported by the CLI; contributing compute has additional hardware requirements.

### Linux

For x86-64 or ARM64 Linux:

```sh
curl -fsSL https://api.heavymetal.network/install.sh | sh
```

The installer downloads the latest CLI release, verifies its SHA-256 checksum, and puts `hmn` in `~/.local/bin`. It requires `curl`, `tar`, and either `sha256sum` or `shasum`.

If `hmn` is not found, add this line to your shell profile and open a new terminal:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

In PowerShell on 64-bit Windows:

```powershell
irm https://api.heavymetal.network/install.ps1 | iex
```

The installer downloads the x64 CLI, verifies its SHA-256 checksum, and installs `hmn.exe` in `$HOME\bin`. It adds that directory to your user PATH.

If you use [Scoop](https://scoop.sh):

```powershell
scoop bucket add heavymetal-network https://github.com/heavymetal-network/scoop-bucket
scoop install heavymetal-network/hmn
```

### Manual download

Download the archive for your operating system and architecture from the [latest release](https://github.com/heavymetal-network/hmn-cli-pub/releases/latest), along with its `hmn_<version>_checksums.txt` file. Compare the archive's SHA-256 hash with the matching entry before extracting it:

- macOS: `shasum -a 256 <archive>`
- Linux: `sha256sum <archive>`
- PowerShell: `Get-FileHash <archive> -Algorithm SHA256`

Extract the archive and put `hmn` (or `hmn.exe`) in a directory on your PATH. You can [read the shell installer](install.sh) or [PowerShell installer](install.ps1) before running it.

## Get started

```sh
hmn --version
hmn setup
hmn status
```

Follow the setup prompts to connect your machine. To connect a supported coding tool, see the available choices:

```sh
hmn configure --help
```

For example, configure Claude Code with:

```sh
hmn configure claude-code
```

Use `hmn --help` to explore commands and `hmn doctor` to check your installation if something goes wrong.

## Update

Use the same method you installed with:

- Homebrew: `brew update && brew upgrade heavymetal-network/tap/hmn`
- Linux or PowerShell installer: run the installation command again.
- Scoop: `scoop update hmn`
- Manual download: replace the binary with the latest verified download.

To select a specific available release with the Linux installer, pass the version to the shell that runs it:

```sh
curl -fsSL https://api.heavymetal.network/install.sh | HMN_VERSION=0.17.77 sh
```

In PowerShell:

```powershell
$env:HMN_VERSION = "0.17.77"
irm https://api.heavymetal.network/install.ps1 | iex
Remove-Item Env:HMN_VERSION
```

Older release assets may be removed, so check that the version is still available on the [releases page](https://github.com/heavymetal-network/hmn-cli-pub/releases).
