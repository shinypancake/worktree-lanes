#!/usr/bin/env bats
# shellcheck shell=bash
load helper

setup() {
  TEST_ROOT="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/locals.worktree.config")"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  cd "$TEST_ROOT"
  # We need the worktree command to resolve WTL_ROOT to the worktree-lanes root
  export WTL_ROOT="$BATS_TEST_DIRNAME/.."
}

@test "test-backend dry-run prints DATABASE_URL containing _test_ and db:prepare" {
  run env WTL_DRYRUN=1 bash "$BATS_TEST_DIRNAME/../libexec/test-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == *"_test_"* ]]
  [[ "$output" == *"db:prepare"* ]]
}
