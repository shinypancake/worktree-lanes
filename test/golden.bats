#!/usr/bin/env bats
# Golden parity tests: generic CLI must reproduce Huddle's captured output byte-for-byte
# (for GOTOGETHER_* prefixed lines; WTL_* neutral aliases are stripped before diffing).

HUDDLE_REPO=/Users/logan/repos/huddle
WTL_REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
HUDDLE_GIT_CTX="$HUDDLE_REPO/.wtl-test-tmp"   # subdirectory inside Huddle for correct git context
WORKTREE_CMD="$WTL_REPO/bin/worktree"
GOLDEN_DIR="$BATS_TEST_DIRNAME/golden"
HUDDLE_CFG="$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config"
LOCALS_CFG="$BATS_TEST_DIRNAME/fixtures/locals.worktree.config"

setup() {
  # Ensure the git context directory exists with config
  mkdir -p "$HUDDLE_GIT_CTX"
  cp "$HUDDLE_CFG" "$HUDDLE_GIT_CTX/worktree.config"
  # Ensure worktree-lanes repo has locals config subdir
  mkdir -p "$WTL_REPO/.wtl-locals-test"
  cp "$LOCALS_CFG" "$WTL_REPO/.wtl-locals-test/worktree.config"
}

@test "huddle profile reproduces captured GOTOGETHER_* env exactly (shell, main)" {
  out="$(cd "$HUDDLE_GIT_CTX" && WTL_FAKE_ROOT="$HUDDLE_REPO" "$WORKTREE_CMD" env --shell \
    | grep -v '^export WTL_')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-main.shell.txt"
}

@test "huddle profile reproduces captured GOTOGETHER_* env exactly (shell, non-main)" {
  out="$(cd "$HUDDLE_GIT_CTX" && WTL_FAKE_ROOT=/private/tmp/hud-wt-parity "$WORKTREE_CMD" env --shell \
    | grep -v '^export WTL_')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-nonmain.shell.txt"
}

@test "huddle profile reproduces captured GOTOGETHER_* env exactly (shell, CI lane)" {
  out="$(cd "$HUDDLE_GIT_CTX" && \
    GITHUB_ACTIONS=true GOTOGETHER_CI_LANE_KEY=gha-1-1-job-runner \
    WTL_FAKE_ROOT="$HUDDLE_REPO" "$WORKTREE_CMD" env --shell \
    | grep -v '^export WTL_')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-ci.shell.txt"
}

@test "huddle profile json output is valid JSON" {
  cd "$HUDDLE_GIT_CTX" && WTL_FAKE_ROOT="$HUDDLE_REPO" "$WORKTREE_CMD" env --json \
    | python3 -c 'import json,sys; json.load(sys.stdin)'
}

@test "huddle profile json byte-diff matches golden (WTL_* stripped)" {
  out="$(cd "$HUDDLE_GIT_CTX" && WTL_FAKE_ROOT="$HUDDLE_REPO" "$WORKTREE_CMD" env --json \
    | sed 's/,"WTL_[^"]*":"[^"]*"//g; s/{"WTL_[^"]*":"[^"]*",//g')"
  diff <(printf '%s\n' "$out") "$GOLDEN_DIR/huddle-main.json.txt"
}

@test "locals profile main golden is stable" {
  out1="$(cd "$WTL_REPO/.wtl-locals-test" && WTL_FAKE_ROOT="$WTL_REPO" "$WORKTREE_CMD" env --shell)"
  diff <(printf '%s\n' "$out1") "$GOLDEN_DIR/locals-main.shell.txt"
}
