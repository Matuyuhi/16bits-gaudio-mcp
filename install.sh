#!/bin/bash
set -euo pipefail

REPO="Matuyuhi/16bits-gaudio-mcp"
BINARY="16bits-audio-mcp"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS and arch
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) os_name="darwin" ;;
  Linux)  os_name="linux" ;;
  *)      echo "Error: unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64)  arch_name="x86_64" ;;
  arm64|aarch64)  arch_name="arm64" ;;
  *)              echo "Error: unsupported architecture: $ARCH"; exit 1 ;;
esac

ARTIFACT="${BINARY}-${os_name}-${arch_name}"

# Get latest version
if [ -z "${VERSION:-}" ]; then
  VERSION=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\(.*\)".*/\1/')
  if [ -z "$VERSION" ]; then
    echo "Error: could not determine latest version. Set VERSION=v0.1.0 manually."
    exit 1
  fi
fi

URL="https://github.com/$REPO/releases/download/$VERSION/${ARTIFACT}.tar.gz"

echo "Installing $BINARY $VERSION ($os_name/$arch_name)..."
echo "  From: $URL"
echo "  To:   $INSTALL_DIR/$BINARY"

# Download and install
mkdir -p "$INSTALL_DIR"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

curl -sL "$URL" | tar xz -C "$TMP"
chmod +x "$TMP/$ARTIFACT"
mv "$TMP/$ARTIFACT" "$INSTALL_DIR/$BINARY"

echo ""
echo "Installed: $INSTALL_DIR/$BINARY"
echo ""

# Check PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo "Note: $INSTALL_DIR is not in your PATH."
  echo "  Add to ~/.zshrc or ~/.bashrc:"
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
fi

# Claude Desktop config hint
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
echo "Claude Desktop config ($CLAUDE_CONFIG):"
echo ""
echo '  {'
echo '    "mcpServers": {'
echo '      "16bits-audio": {'
echo "        \"command\": \"$INSTALL_DIR/$BINARY\""
echo '      }'
echo '    }'
echo '  }'
