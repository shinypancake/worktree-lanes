#!/usr/bin/env bats
load helper
setup() {
  . "$BATS_TEST_DIRNAME/../lib/config.sh"
  . "$BATS_TEST_DIRNAME/../lib/derive.sh"
  root="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config")"
  cd "$root"
  wtl_load_config
}

@test "worktree id is sha256[0:8] of the worktree root, stable" {
  wtl_derive
  id1="$WTL_WORKTREE_ID"
  wtl_derive
  [ "$WTL_WORKTREE_ID" = "$id1" ]
  expect="$(printf '%s' "$WTL_WORKTREE_ROOT" | shasum -a 256 | cut -c1-8)"
  [ "$WTL_WORKTREE_ID" = "$expect" ]
}

@test "test db name is always per-id" {
  wtl_derive
  [ "$WTL_TEST_DB_NAME" = "gotogether_test_${WTL_WORKTREE_ID}" ]
}

@test "non-main postgres port = base + slot" {
  # Use a fake root that is different from MAIN_REPO to force non-main mode
  WTL_FAKE_ROOT="$root/nonmain-branch"
  wtl_derive
  slot=$(( $(printf '%d' "0x$(printf '%s' "$WTL_FAKE_ROOT" | shasum -a256 | cut -c1-6)") % 200 ))
  [ "$WTL_POSTGRES_PORT" = "$(( 47000 + slot ))" ]
}
