#!/usr/bin/env bats
load helper

# Helper: run `worktree env` from a config root
worktree_env_shell() {
  local config_file="$1"
  local root; root="$(setup_repo_root "$config_file")"
  ( cd "$root" && WTL_ROOT="$BATS_TEST_DIRNAME/.." "$BATS_TEST_DIRNAME/../bin/worktree" env --shell )
}

worktree_env_json() {
  local config_file="$1"
  local root; root="$(setup_repo_root "$config_file")"
  ( cd "$root" && WTL_ROOT="$BATS_TEST_DIRNAME/.." "$BATS_TEST_DIRNAME/../bin/worktree" env --json )
}

@test "emits both prefixed and neutral names in shell mode" {
  run worktree_env_shell "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export GOTOGETHER_TEST_DB_NAME="* ]]
  [[ "$output" == *"export WTL_TEST_DB_NAME="* ]]
}

@test "json mode is valid json with prefixed keys" {
  run worktree_env_json "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; json.load(sys.stdin)'
  [[ "$output" == *'"GOTOGETHER_TEST_DB_NAME"'* ]]
}

@test "emits WTL_TEST_DB_NAME neutral alias" {
  run worktree_env_shell "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export WTL_TEST_DB_NAME=gotogether_test_"* ]]
}
