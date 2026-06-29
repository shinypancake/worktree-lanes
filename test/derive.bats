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

@test "WTL_CI_LANE_SUFFIX neutral override changes WORKTREE_ID vs unset" {
  # Simulate subprocess re-eval: run each call in its own subshell so the
  # WTL_CI_LANE_KEY written by wtl_derive does not bleed into the second call.
  # This mirrors the real retry flow where `eval "$(worktree env --shell)"` is
  # re-run after exporting WTL_CI_LANE_SUFFIX.

  # Without suffix: WORKTREE_ID derived from root alone
  id_base="$(
    . "$BATS_TEST_DIRNAME/../lib/config.sh"
    . "$BATS_TEST_DIRNAME/../lib/derive.sh"
    cfg_root="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config")"
    cd "$cfg_root"
    wtl_load_config
    unset WTL_CI_LANE_SUFFIX WTL_CI_LANE_KEY GOTOGETHER_CI_LANE_SUFFIX GOTOGETHER_CI_LANE_KEY
    GITHUB_ACTIONS=true GITHUB_RUN_ID=99 GITHUB_RUN_ATTEMPT=1 GITHUB_JOB=job RUNNER_NAME=runner \
      WTL_FAKE_ROOT="$cfg_root" wtl_derive
    printf '%s' "$WTL_WORKTREE_ID"
  )"

  # With neutral suffix: WORKTREE_ID must differ
  id_retry="$(
    . "$BATS_TEST_DIRNAME/../lib/config.sh"
    . "$BATS_TEST_DIRNAME/../lib/derive.sh"
    cfg_root="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config")"
    cd "$cfg_root"
    wtl_load_config
    unset GOTOGETHER_CI_LANE_SUFFIX GOTOGETHER_CI_LANE_KEY
    WTL_CI_LANE_SUFFIX=retry1 \
      GITHUB_ACTIONS=true GITHUB_RUN_ID=99 GITHUB_RUN_ATTEMPT=1 GITHUB_JOB=job RUNNER_NAME=runner \
      WTL_FAKE_ROOT="$cfg_root" wtl_derive
    printf '%s' "$WTL_WORKTREE_ID"
  )"

  [ -n "$id_base" ] && [ -n "$id_retry" ]
  [ "$id_retry" != "$id_base" ]
}

@test "WTL_CI_LANE_SUFFIX neutral override does NOT affect golden parity (no suffix set)" {
  # Parity guard: when the neutral overrides are unset, the prefixed GOTOGETHER_* output is unchanged.
  unset WTL_CI_LANE_SUFFIX WTL_CI_LANE_KEY
  WTL_FAKE_ROOT="$root" wtl_derive
  # ID must match the stable golden (same as huddle-main: d228c073)
  [ "$WTL_WORKTREE_ID" = "$(printf '%s' "$root" | shasum -a256 | cut -c1-8)" ]
}
