#!/usr/bin/env bats
# shellcheck shell=bash
load helper

setup() {
  TEST_ROOT="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/locals.worktree.config")"
  export WTL_ROOT="$BATS_TEST_DIRNAME/.."
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  cd "$TEST_ROOT"
}

@test "lane-ports prints resolved ports for all six services" {
  run worktree lane-ports
  [ "$status" -eq 0 ]
  # Should include backend, frontend, mailhog_ui, mailhog_smtp, postgres, redis ports
  [[ "$output" == *"LOCALS_BACKEND_PORT"* ]]
  [[ "$output" == *"LOCALS_FRONTEND_PORT"* ]]
  [[ "$output" == *"LOCALS_POSTGRES_PORT"* ]]
  [[ "$output" == *"LOCALS_REDIS_PORT"* ]]
  [[ "$output" == *"LOCALS_MAILHOG_UI_PORT"* ]]
  [[ "$output" == *"LOCALS_MAILHOG_SMTP_PORT"* ]]
}

@test "lane-ports main worktree shows canonical ports" {
  run worktree lane-ports
  [ "$status" -eq 0 ]
  [[ "$output" == *"3001"* ]]
  [[ "$output" == *"5174"* ]]
  [[ "$output" == *"5433"* ]]
  [[ "$output" == *"6380"* ]]
}
