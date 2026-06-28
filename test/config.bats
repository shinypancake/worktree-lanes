#!/usr/bin/env bats
load helper
setup() { . "$BATS_TEST_DIRNAME/../lib/config.sh"; }

@test "loads config by walking up from cwd" {
  root="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/locals.worktree.config")"
  mkdir -p "$root/backend/deep"; cd "$root/backend/deep"
  wtl_load_config
  [ "$WTL_CFG_PROJECT" = "locals" ]
  [ "$WTL_CFG_PREFIX" = "LOCALS" ]
  [ "$WTL_CFG_MAIN_POSTGRES_PORT" = "5433" ]
  [ "$WTL_CFG_NONMAIN_POSTGRES_PORT_BASE" = "47000" ]   # default applied
}

@test "aborts with guidance when no config present" {
  cd "$(mktemp -d)"
  run wtl_load_config
  [ "$status" -ne 0 ]
  [[ "$output" == *"worktree.config"* ]]
}
