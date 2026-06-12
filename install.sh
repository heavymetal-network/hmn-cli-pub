#!/usr/bin/env sh
set -e

# HeavyMetal Network CLI installer
# Usage: curl -sSL https://raw.githubusercontent.com/heavymetal-network/hmn-cli-pub/main/install.sh | sh
# Version-pinned: HMN_VERSION=0.1.0 curl -sSL ... | sh

REPO="heavymetal-network/hmn-cli-pub"
BINARY="hmn"
INSTALL_DIR="${HOME}/.local/bin"

OS="$(uname -s)"
case "${OS}" in
  Linux*)  OS=linux ;;
  Darwin*) OS=darwin ;;
  *)       echo "Unsupported OS: ${OS}" >&2; exit 1 ;;
esac

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64)  ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *)             echo "Unsupported arch: ${ARCH}" >&2; exit 1 ;;
esac

if [ -z "${HMN_VERSION}" ]; then
  echo "Fetching latest hmn-cli release..."
  LATEST="$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest")"
  TAG="$(printf '%s' "${LATEST}" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
  VERSION="$(printf '%s' "${TAG}" | sed 's|^v||')"
else
  VERSION="${HMN_VERSION}"
fi

[ -z "${VERSION}" ] && { echo "Could not determine version. Set HMN_VERSION=x.y.z to override." >&2; exit 1; }

echo "Installing hmn v${VERSION} (${OS}/${ARCH})..."

ARCHIVE="hmn_${VERSION}_${OS}_${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

curl -sSL --fail "${BASE_URL}/${ARCHIVE}" -o "${TMP}/${ARCHIVE}"
curl -sSL --fail "${BASE_URL}/hmn_${VERSION}_checksums.txt" -o "${TMP}/checksums.txt"

cd "${TMP}"
# macOS ships a BSD sha256sum that doesn't accept --check/--status (GNU flags).
# Prefer shasum on Darwin (always available, supports --check --status correctly).
if [ "${OS}" = "darwin" ] && command -v shasum > /dev/null 2>&1; then
  grep "${ARCHIVE}" checksums.txt | shasum -a 256 --check --status
elif command -v sha256sum > /dev/null 2>&1; then
  grep "${ARCHIVE}" checksums.txt | sha256sum --check --status
elif command -v shasum > /dev/null 2>&1; then
  grep "${ARCHIVE}" checksums.txt | shasum -a 256 --check --status
else
  echo "Warning: no sha256 tool found, skipping checksum verification" >&2
fi

tar -xzf "${ARCHIVE}" -C "${TMP}"

mkdir -p "${INSTALL_DIR}"
mv "${TMP}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
chmod 755 "${INSTALL_DIR}/${BINARY}"

# macOS Gatekeeper: clear the quarantine attribute so the binary runs without
# "Apple cannot check it for malicious software" security prompts.
if [ "${OS}" = "darwin" ]; then
  xattr -d com.apple.quarantine "${INSTALL_DIR}/${BINARY}" 2>/dev/null || true
fi

echo ""
echo "hmn v${VERSION} installed to ${INSTALL_DIR}/${BINARY}"

# Add to PATH if not already there
if ! echo "${PATH}" | grep -q "${INSTALL_DIR}"; then
  SHELL_RC=""
  case "$(basename "${SHELL}")" in
    zsh)  SHELL_RC="${HOME}/.zshrc" ;;
    bash)
      if [ -f "${HOME}/.bashrc" ]; then
        SHELL_RC="${HOME}/.bashrc"
      else
        SHELL_RC="${HOME}/.bash_profile"
      fi
      ;;
  esac

  if [ -n "${SHELL_RC}" ] && ! grep -q "${INSTALL_DIR}" "${SHELL_RC}" 2>/dev/null; then
    printf '\n# hmn-cli\nexport PATH="%s:$PATH"\n' "${INSTALL_DIR}" >> "${SHELL_RC}"
    echo "Added ${INSTALL_DIR} to PATH in ${SHELL_RC}"
    echo "Restart your terminal or run: source ${SHELL_RC}"
  else
    echo ""
    echo "Add to your shell profile to use hmn from any directory:"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
  fi
fi
