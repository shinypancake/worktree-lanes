#!/usr/bin/env bash
# worktree-lanes installer — POSIX/bash, no sudo. Works on macOS, Linux, WSL, and Git Bash.
#
#   curl -fsSL https://raw.githubusercontent.com/shinypancake/worktree-lanes/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --version v0.1.8
#   ./install.sh --version v0.1.8 --bin-dir "$HOME/bin"
#
# Clones the repo to a stable location and symlinks bin/worktree onto PATH, so
# `worktree <subcommand>` is callable directly (not only inside `npm run` scripts).
# Update later with `worktree self-update`.
set -euo pipefail

REPO_URL="https://github.com/shinypancake/worktree-lanes.git"
INSTALL_DIR="${WTL_HOME:-$HOME/.local/share/worktree-lanes}"
BIN_DIR="${WTL_BIN_DIR:-$HOME/.local/bin}"
VERSION=""

usage() {
  cat <<'EOF'
usage: install.sh [--version <tag>] [--bin-dir <dir>] [--dir <install-dir>]

  --version <tag>   Install a specific git tag (default: latest release tag).
  --bin-dir <dir>   Where to symlink the `worktree` launcher (default: ~/.local/bin).
  --dir <dir>       Where to keep the checkout (default: ~/.local/share/worktree-lanes).

Env overrides: WTL_HOME (install dir), WTL_BIN_DIR (bin dir).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?--version needs a value}"; shift 2 ;;
    --version=*) VERSION="${1#*=}"; shift ;;
    --bin-dir) BIN_DIR="${2:?--bin-dir needs a value}"; shift 2 ;;
    --bin-dir=*) BIN_DIR="${1#*=}"; shift ;;
    --dir) INSTALL_DIR="${2:?--dir needs a value}"; shift 2 ;;
    --dir=*) INSTALL_DIR="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "install: git is required but not found on PATH" >&2; exit 1; }

# Fetch (or refresh) the checkout.
if [ -d "$INSTALL_DIR/.git" ]; then
  git -C "$INSTALL_DIR" remote set-url origin "$REPO_URL"
  git -C "$INSTALL_DIR" fetch --tags --force --quiet origin
else
  rm -rf "$INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

# Resolve the ref: explicit --version, else the newest release tag, else the default branch.
if [ -z "$VERSION" ]; then
  VERSION="$(git -C "$INSTALL_DIR" for-each-ref --sort=-v:refname --count=1 --format='%(refname:short)' refs/tags)"
fi
if [ -n "$VERSION" ]; then
  git -C "$INSTALL_DIR" checkout --quiet "$VERSION"
else
  git -C "$INSTALL_DIR" checkout --quiet "$(git -C "$INSTALL_DIR" symbolic-ref --short HEAD 2>/dev/null || echo main)"
fi

# Symlink the launcher onto PATH (the CLI resolves its own root through the symlink).
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/worktree" "$BIN_DIR/worktree"

echo "worktree-lanes installed: $BIN_DIR/worktree (version $("$BIN_DIR/worktree" version 2>/dev/null || echo unknown))"

case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *)
    echo ""
    echo "NOTE: $BIN_DIR is not on your PATH. Add it:"
    echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc   # or ~/.zshrc / ~/.profile"
    echo "  export PATH=\"$BIN_DIR:\$PATH\"                        # for the current shell"
    ;;
esac
