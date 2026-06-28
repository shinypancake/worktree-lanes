#!/usr/bin/env bash
# Recapture Huddle golden fixtures from the live Huddle checkout.
# Run this when Huddle's bin/worktree-env changes and golden files need updating.
set -euo pipefail

HUDDLE_REPO=/Users/logan/repos/huddle
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/golden"
CFG_DIR="$SCRIPT_DIR/fixtures"

# Ensure Huddle git context dir + config
mkdir -p "$HUDDLE_REPO/.wtl-test-tmp"
cp "$CFG_DIR/huddle.worktree.config" "$HUDDLE_REPO/.wtl-test-tmp/worktree.config"

echo "Capturing main worktree golden..."
( cd "$HUDDLE_REPO" && bin/worktree-env --shell ) > "$GOLDEN_DIR/huddle-main.shell.txt"
( cd "$HUDDLE_REPO" && bin/worktree-env --json )  > "$GOLDEN_DIR/huddle-main.json.txt"

echo "Capturing CI lane golden..."
( cd "$HUDDLE_REPO" && GITHUB_ACTIONS=true GOTOGETHER_CI_LANE_KEY=gha-1-1-job-runner \
    bin/worktree-env --shell ) > "$GOLDEN_DIR/huddle-ci.shell.txt"

echo "Capturing non-main worktree golden..."
git -C "$HUDDLE_REPO" worktree add --detach /tmp/hud-wt-parity 2>/dev/null || true
( cd /tmp/hud-wt-parity && "$HUDDLE_REPO/bin/worktree-env" --shell ) > "$GOLDEN_DIR/huddle-nonmain.shell.txt"
git -C "$HUDDLE_REPO" worktree remove --force /tmp/hud-wt-parity

echo "Done. Golden files updated in $GOLDEN_DIR"
