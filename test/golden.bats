#!/usr/bin/env bats
# Golden parity tests: generic CLI must reproduce Huddle's captured output byte-for-byte
# (for GOTOGETHER_* prefixed lines; WTL_* neutral aliases are stripped before diffing).

HUDDLE_REPO=/Users/logan/repos/huddle
WTL_REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
WORKTREE_CMD="$WTL_REPO/bin/worktree"
GOLDEN_DIR="$BATS_TEST_DIRNAME/golden"
HUDDLE_CFG="$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config"
LOCALS_CFG="$BATS_TEST_DIRNAME/fixtures/locals.worktree.config"

setup() {
  # Create a portable temp dir with the huddle config; no dependency on /Users/logan existing.
  HUDDLE_TMP="$(mktemp -d)"
  cp "$HUDDLE_CFG" "$HUDDLE_TMP/worktree.config"
  # Create a portable temp dir with the locals config.
  LOCALS_TMP="$(mktemp -d)"
  cp "$LOCALS_CFG" "$LOCALS_TMP/worktree.config"
  # Unset GHA env so the non-CI golden tests don't pick up CI lane logic from the runner.
  # Tests that need CI behavior (huddle-ci.shell.txt) set GITHUB_ACTIONS=true explicitly.
  unset GITHUB_ACTIONS GITHUB_RUN_ID GITHUB_RUN_ATTEMPT GITHUB_JOB RUNNER_NAME
}

teardown() {
  rm -rf "${HUDDLE_TMP:-}" "${LOCALS_TMP:-}"
}

# Common env for huddle golden tests:
#   WTL_FAKE_MAIN_REPO  — skips git worktree list, injects the captured main-repo path
#   WTL_FAKE_CONTAINER_UID/GID — pins id -u/id -g to captured macOS values
#   GOTOGETHER_FRONTEND_CONTAINER_UID/GID=0 — reproduces the Darwin local-dev override
_huddle_env() {
  printf '%s' \
    "WTL_FAKE_MAIN_REPO=$HUDDLE_REPO " \
    "WTL_FAKE_CONTAINER_UID=501 " \
    "WTL_FAKE_CONTAINER_GID=20 " \
    "GOTOGETHER_FRONTEND_CONTAINER_UID=0 " \
    "GOTOGETHER_FRONTEND_CONTAINER_GID=0"
}

@test "huddle profile reproduces captured GOTOGETHER_* env exactly (shell, main)" {
  out="$(cd "$HUDDLE_TMP" && \
    WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
    WTL_FAKE_ROOT="$HUDDLE_REPO" \
    WTL_FAKE_CONTAINER_UID=501 \
    WTL_FAKE_CONTAINER_GID=20 \
    GOTOGETHER_FRONTEND_CONTAINER_UID=0 \
    GOTOGETHER_FRONTEND_CONTAINER_GID=0 \
    "$WORKTREE_CMD" env --shell \
    | grep -v '^export WTL_')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-main.shell.txt"
}

@test "huddle profile reproduces captured GOTOGETHER_* env exactly (shell, non-main)" {
  out="$(cd "$HUDDLE_TMP" && \
    WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
    WTL_FAKE_ROOT=/private/tmp/hud-wt-parity \
    WTL_FAKE_CONTAINER_UID=501 \
    WTL_FAKE_CONTAINER_GID=20 \
    GOTOGETHER_FRONTEND_CONTAINER_UID=0 \
    GOTOGETHER_FRONTEND_CONTAINER_GID=0 \
    "$WORKTREE_CMD" env --shell \
    | grep -v '^export WTL_')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-nonmain.shell.txt"
}

@test "huddle profile reproduces captured GOTOGETHER_* env exactly (shell, CI lane)" {
  out="$(cd "$HUDDLE_TMP" && \
    GITHUB_ACTIONS=true GOTOGETHER_CI_LANE_KEY=gha-1-1-job-runner \
    WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
    WTL_FAKE_ROOT="$HUDDLE_REPO" \
    WTL_FAKE_CONTAINER_UID=501 \
    WTL_FAKE_CONTAINER_GID=20 \
    "$WORKTREE_CMD" env --shell \
    | grep -v '^export WTL_')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-ci.shell.txt"
}

@test "huddle profile json output is valid JSON" {
  cd "$HUDDLE_TMP" && \
    WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
    WTL_FAKE_ROOT="$HUDDLE_REPO" \
    WTL_FAKE_CONTAINER_UID=501 \
    WTL_FAKE_CONTAINER_GID=20 \
    GOTOGETHER_FRONTEND_CONTAINER_UID=0 \
    GOTOGETHER_FRONTEND_CONTAINER_GID=0 \
    "$WORKTREE_CMD" env --json \
    | python3 -c 'import json,sys; json.load(sys.stdin)'
}

@test "huddle profile json byte-diff matches golden (WTL_* stripped)" {
  out="$(cd "$HUDDLE_TMP" && \
    WTL_FAKE_MAIN_REPO="$HUDDLE_REPO" \
    WTL_FAKE_ROOT="$HUDDLE_REPO" \
    WTL_FAKE_CONTAINER_UID=501 \
    WTL_FAKE_CONTAINER_GID=20 \
    GOTOGETHER_FRONTEND_CONTAINER_UID=0 \
    GOTOGETHER_FRONTEND_CONTAINER_GID=0 \
    "$WORKTREE_CMD" env --json \
    | sed 's/,"WTL_[^"]*":"[^"]*"//g; s/{"WTL_[^"]*":"[^"]*",//g')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-main.json.txt"
}

LOCALS_REPO=/Users/logan/repos/worktree-lanes

@test "locals profile main golden is stable" {
  out1="$(cd "$LOCALS_TMP" && \
    WTL_FAKE_ROOT="$LOCALS_REPO" \
    WTL_FAKE_MAIN_REPO="$LOCALS_REPO" \
    WTL_FAKE_CONTAINER_UID=501 \
    WTL_FAKE_CONTAINER_GID=20 \
    LOCALS_FRONTEND_CONTAINER_UID=0 \
    LOCALS_FRONTEND_CONTAINER_GID=0 \
    "$WORKTREE_CMD" env --shell)"
  diff <(printf '%s\n' "$out1") "$GOLDEN_DIR/locals-main.shell.txt"
}
