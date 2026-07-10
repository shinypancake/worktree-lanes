#!/usr/bin/env bash
# Recapture Huddle golden fixtures from the live Huddle checkout.
# Run this when the CLI output format changes and golden files need updating.
#
# Goldens are captured from the generic CLI (./bin/worktree env) using WTL_FAKE_*
# overrides to pin non-deterministic values (see test/golden.bats for the same pattern).
# The legacy bin/worktree-env script was removed from Huddle main; this script now
# exercises the actual CLI under test.
set -euo pipefail

HUDDLE_REPO=/Users/logan/repos/huddle
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/golden"
CFG_DIR="$SCRIPT_DIR/fixtures"
WORKTREE_CMD="$SCRIPT_DIR/../bin/worktree"

# Ensure Huddle git context dir + config
mkdir -p "$HUDDLE_REPO/.wtl-test-tmp"
cp "$CFG_DIR/huddle.worktree.config" "$HUDDLE_REPO/.wtl-test-tmp/worktree.config"

echo "Capturing main worktree golden..."
( cd "$HUDDLE_REPO" && \
  WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
  WTL_FAKE_CONTAINER_UID=501 \
  WTL_FAKE_CONTAINER_GID=20 \
  HUDDLE_FRONTEND_CONTAINER_UID=0 \
  HUDDLE_FRONTEND_CONTAINER_GID=0 \
  "$WORKTREE_CMD" env --shell ) > "$GOLDEN_DIR/huddle-main.shell.txt"
( cd "$HUDDLE_REPO" && \
  WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
  WTL_FAKE_CONTAINER_UID=501 \
  WTL_FAKE_CONTAINER_GID=20 \
  HUDDLE_FRONTEND_CONTAINER_UID=0 \
  HUDDLE_FRONTEND_CONTAINER_GID=0 \
  "$WORKTREE_CMD" env --json ) > "$GOLDEN_DIR/huddle-main.json.txt"

echo "Capturing CI lane golden..."
( cd "$HUDDLE_REPO" && \
  GITHUB_ACTIONS=true HUDDLE_CI_LANE_KEY=gha-1-1-job-runner \
  WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
  WTL_FAKE_CONTAINER_UID=501 \
  WTL_FAKE_CONTAINER_GID=20 \
  HUDDLE_FRONTEND_CONTAINER_UID=0 \
  HUDDLE_FRONTEND_CONTAINER_GID=0 \
  "$WORKTREE_CMD" env --shell ) > "$GOLDEN_DIR/huddle-ci.shell.txt"

echo "Capturing non-main worktree golden..."
git -C "$HUDDLE_REPO" worktree add --detach /tmp/hud-wt-parity 2>/dev/null || true
( cd /tmp/hud-wt-parity && \
  WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
  WTL_FAKE_CONTAINER_UID=501 \
  WTL_FAKE_CONTAINER_GID=20 \
  HUDDLE_FRONTEND_CONTAINER_UID=0 \
  HUDDLE_FRONTEND_CONTAINER_GID=0 \
  "$WORKTREE_CMD" env --shell ) > "$GOLDEN_DIR/huddle-nonmain.shell.txt"
git -C "$HUDDLE_REPO" worktree remove --force /tmp/hud-wt-parity

echo "Done. Golden files updated in $GOLDEN_DIR"
