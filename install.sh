#!/usr/bin/env sh
set -e

# HeavyMetal Network CLI installer
#
#   curl -fsSL https://api.heavymetal.network/install.sh | bash
#
#   macOS   - Homebrew (installs Homebrew first if it's missing)
#   Linux   - direct binary into ~/.local/bin
#   Windows - use install.ps1 / Scoop (see message below)
#
# Pin a version:   curl -fsSL ... | HMN_VERSION=0.17.77 sh   (Linux only; brew is always latest)
# Dry run:         HMN_INSTALL_DRY_RUN=1 ...                    (print actions, change nothing)
# Force OS (test): HMN_INSTALL_OS=linux HMN_INSTALL_DRY_RUN=1 sh install.sh

REPO="heavymetal-network/hmn-cli-pub"
TAP="heavymetal-network/tap"   # `brew install heavymetal-network/tap/hmn` auto-taps homebrew-tap
BINARY="hmn"
INSTALL_DIR="${HOME}/.local/bin"

info() { printf '%s\n' "$*"; }
err()  { printf 'error: %s\n' "$*" >&2; }

# run executes a command, or just prints it (prefixed with +) in dry-run mode.
run() {
  if [ -n "${HMN_INSTALL_DRY_RUN}" ]; then
    printf '+ %s\n' "$*"
  else
    eval "$*"
  fi
}

# --- Detect OS (HMN_INSTALL_OS overrides, for dry-run testing of each branch) ---
if [ -n "${HMN_INSTALL_OS}" ]; then
  OS="${HMN_INSTALL_OS}"
else
  case "$(uname -s)" in
    Darwin*)              OS=darwin ;;
    Linux*)               OS=linux ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    *)                    err "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
fi

# --- Load Homebrew onto PATH if installed but not exported (non-login shells) ---
# Sets BREW_SHELLENV_BIN to the brew binary that worked, so the post-install
# message can name the exact path (/opt/homebrew on Apple Silicon, /usr/local on Intel).
BREW_SHELLENV_BIN=""
load_brew() {
  if command -v brew >/dev/null 2>&1; then
    BREW_SHELLENV_BIN="$(command -v brew)"
    return 0
  fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "${b}" ]; then
      eval "$("${b}" shellenv)"
      BREW_SHELLENV_BIN="${b}"
      return 0
    fi
  done
  return 1
}

install_macos() {
  brew_needs_path=0
  command -v brew >/dev/null 2>&1 || brew_needs_path=1
  if ! load_brew; then
    info "Homebrew is required and not installed. Installing Homebrew first..."
    # NONINTERACTIVE=1 keeps the official installer from prompting; it still reads
    # sudo from the controlling terminal when needed.
    run 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    load_brew || true
  fi

  if [ -z "${HMN_INSTALL_DRY_RUN}" ] && ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is not available after install. Install it from https://brew.sh then re-run."
    exit 1
  fi

  if [ -z "${HMN_INSTALL_DRY_RUN}" ] && brew list "${TAP}/${BINARY}" >/dev/null 2>&1; then
    info "hmn is already installed via Homebrew - upgrading..."
    run "brew update"
    run "brew upgrade ${TAP}/${BINARY}"
  else
    info "Installing hmn via Homebrew..."
    run "brew install ${TAP}/${BINARY}"
  fi

  info ""
  info "hmn installed."

  # Loading shellenv changes this process only; the caller still needs it.
  if [ -z "${HMN_INSTALL_DRY_RUN}" ] && [ "${brew_needs_path}" = 1 ]; then
    brew_bin="${BREW_SHELLENV_BIN:-/opt/homebrew/bin/brew}"
    case "${SHELL:-}" in
      */bash) prof='$HOME/.bash_profile' ;;
      *) prof='$HOME/.zprofile' ;;
    esac
    info ""
    info "Homebrew (and hmn) are not on your PATH yet."
    info "   Add Homebrew to your PATH, then re-open your terminal or run:"
    info ""
    info "     echo 'eval \"\$(${brew_bin} shellenv)\"' >> \"${prof}\""
    info "     eval \"\$(${brew_bin} shellenv)\""
    info ""
    info "   Then run: hmn setup"
  else
    info "Next: run 'hmn setup' to get started."
  fi
}

install_linux() {
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64)  ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *)             err "Unsupported arch: ${ARCH}"; exit 1 ;;
  esac

  if [ -n "${HMN_VERSION}" ]; then
    VERSION="${HMN_VERSION}"
  elif [ -n "${HMN_INSTALL_DRY_RUN}" ]; then
    VERSION="<latest>"
  else
    info "Fetching latest hmn-cli release..."
    LATEST="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")"
    TAG="$(printf '%s' "${LATEST}" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
    VERSION="$(printf '%s' "${TAG}" | sed 's|^v||')"
    [ -z "${VERSION}" ] && { err "Could not determine version. Set HMN_VERSION=x.y.z to override."; exit 1; }
  fi

  if [ -z "${HMN_INSTALL_DRY_RUN}" ] || [ -n "${HMN_VERSION}" ]; then
    VERSION="${VERSION#v}"
    if ! printf '%s\n' "${VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
      err "Invalid version. Set HMN_VERSION to a release version such as 0.17.77."
      exit 1
    fi
  fi

  info "Installing hmn v${VERSION} (linux/${ARCH}) to ${INSTALL_DIR}..."
  ARCHIVE="hmn_${VERSION}_linux_${ARCH}.tar.gz"
  BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"

  if [ -n "${HMN_INSTALL_DRY_RUN}" ]; then
    run "curl -fsSL ${BASE_URL}/${ARCHIVE} -o <tmp>/${ARCHIVE}  # + checksum verify"
    run "tar -xzf ${ARCHIVE} && mv ${BINARY} ${INSTALL_DIR}/${BINARY}"
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    checksum_tool=sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    checksum_tool=shasum
  else
    err "SHA-256 verification requires sha256sum or shasum. Install one and retry."
    exit 1
  fi

  TMP="$(mktemp -d)"
  trap 'rm -rf "${TMP}"' EXIT
  curl -fsSL "${BASE_URL}/${ARCHIVE}" -o "${TMP}/${ARCHIVE}"
  curl -fsSL "${BASE_URL}/hmn_${VERSION}_checksums.txt" -o "${TMP}/checksums.txt"
  cd "${TMP}"
  # Accept exactly one checksum for this archive, never a substring match.
  if ! awk -v archive="${ARCHIVE}" '
    NF == 2 && ($2 == archive || $2 == "*" archive) {
      if (length($1) != 64 || $1 ~ /[^0-9a-fA-F]/) exit 1
      print $1 "  " archive
      count++
    }
    END { if (count != 1) exit 1 }
  ' checksums.txt > selected-checksum.txt; then
    err "Expected exactly one valid SHA-256 checksum for ${ARCHIVE}."
    exit 1
  fi
  if [ "${checksum_tool}" = sha256sum ]; then
    sha256sum --check --status selected-checksum.txt
  else
    shasum -a 256 --check --status selected-checksum.txt
  fi
  tar -xzf "${ARCHIVE}" -C "${TMP}"
  mkdir -p "${INSTALL_DIR}"
  mv "${TMP}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
  chmod 755 "${INSTALL_DIR}/${BINARY}"

  info ""
  info "hmn v${VERSION} installed to ${INSTALL_DIR}/${BINARY}"
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
    info "Add ${INSTALL_DIR} to your PATH:"
    info '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
  esac
  info "Next: run 'hmn setup' to get started."
}

case "${OS}" in
  darwin) install_macos ;;
  linux)  install_linux ;;
  windows)
    err "Windows detected - this shell installer doesn't run there."
    err "In PowerShell, run:"
    err "  irm https://api.heavymetal.network/install.ps1 | iex"
    err "See https://github.com/heavymetal-network/hmn-cli-pub#install for more options."
    exit 1 ;;
  *) err "Unsupported OS: ${OS}"; exit 1 ;;
esac
