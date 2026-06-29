#!/usr/bin/env bats
# Tests for db-drop, db-prune, and worktree version.
# shellcheck shell=bash
load helper

setup() {
  TEST_ROOT="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/locals.worktree.config")"
  export WTL_ROOT="$BATS_TEST_DIRNAME/.."
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  cd "$TEST_ROOT"
}

# ---------------------------------------------------------------------------
# worktree version
# ---------------------------------------------------------------------------

@test "worktree version prints the VERSION file contents" {
  run worktree version
  [ "$status" -eq 0 ]
  expected="$(cat "$BATS_TEST_DIRNAME/../VERSION")"
  [ "$output" = "$expected" ]
}

@test "worktree --version prints the same version" {
  run worktree --version
  [ "$status" -eq 0 ]
  expected="$(cat "$BATS_TEST_DIRNAME/../VERSION")"
  [ "$output" = "$expected" ]
}

@test "worktree version output matches 0.1.1" {
  run worktree version
  [ "$status" -eq 0 ]
  [[ "$output" == *"0.1.1"* ]]
}

# ---------------------------------------------------------------------------
# db-drop dry-run
# ---------------------------------------------------------------------------

@test "db-drop dry-run prints drop targeting WTL_TEST_DB_NAME" {
  run env WTL_DRYRUN=1 bash "$BATS_TEST_DIRNAME/../libexec/db-drop"
  [ "$status" -eq 0 ]
  # Must mention the test db name (locals_test_<id>)
  [[ "$output" == *"locals_test_"* ]]
  # Must NOT mention dev db when --dev not given
  [[ "$output" != *"locals_dev_"* ]]
}

@test "db-drop --dev dry-run also prints drop for WTL_DEV_DB_NAME" {
  # Use WTL_FAKE_ROOT pointing to a non-main path to force per-id dev db naming.
  NONMAIN_ROOT="$TEST_ROOT/feature-branch"
  run env WTL_FAKE_ROOT="$NONMAIN_ROOT" WTL_DRYRUN=1 bash "$BATS_TEST_DIRNAME/../libexec/db-drop" --dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"locals_test_"* ]]
  [[ "$output" == *"locals_dev_"* ]]
}

@test "db-drop dry-run targets the shared-PG host and port" {
  run env WTL_DRYRUN=1 bash "$BATS_TEST_DIRNAME/../libexec/db-drop"
  [ "$status" -eq 0 ]
  # locals fixture uses WTL_MAIN_POSTGRES_PORT=5433
  [[ "$output" == *"--port=5433"* ]]
  [[ "$output" == *"--host=127.0.0.1"* ]]
}

@test "db-drop exits 0 on --help" {
  run bash "$BATS_TEST_DIRNAME/../libexec/db-drop" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "db-drop rejects unknown args" {
  run env WTL_DRYRUN=1 bash "$BATS_TEST_DIRNAME/../libexec/db-drop" --bogus
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# db-prune dry-run (no real Postgres needed — inject via WTL_PRUNE_DB_LIST_CMD)
# ---------------------------------------------------------------------------

setup_prune_env() {
  # Compute the live-worktree id for TEST_ROOT so we can fabricate an orphan.
  LIVE_ID="$(
    . "$BATS_TEST_DIRNAME/../lib/derive.sh"
    wtl_id_for_path "$TEST_ROOT"
  )"
  ORPHAN_ID="deadbeef"  # definitely not a live worktree id
  # Fabricated list: one live, one orphan (test DBs)
  export WTL_PRUNE_DB_LIST_CMD="printf '%s\n' 'locals_test_${LIVE_ID}' 'locals_test_${ORPHAN_ID}'"
  # Inject the live worktree path so db-prune doesn't call real `git worktree list`
  export WTL_PRUNE_WORKTREE_LIST_CMD="printf '%s\n' '$TEST_ROOT'"
}

@test "db-prune dry-run: lists orphan as 'Would drop', does NOT list live-id db" {
  setup_prune_env
  run bash "$BATS_TEST_DIRNAME/../libexec/db-prune"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would drop: locals_test_${ORPHAN_ID}"* ]]
  [[ "$output" != *"Would drop: locals_test_${LIVE_ID}"* ]]
}

@test "db-prune dry-run: does NOT pass --apply by default (safe convention)" {
  setup_prune_env
  # Verify the default mode is dry-run by checking the summary line
  run bash "$BATS_TEST_DIRNAME/../libexec/db-prune"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
}

@test "db-prune dry-run summary shows would_drop=1 kept=1" {
  setup_prune_env
  run bash "$BATS_TEST_DIRNAME/../libexec/db-prune"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would_drop=1"* ]]
  [[ "$output" == *"kept=1"* ]]
}

@test "db-prune does not drop bare project_test (no id suffix)" {
  # Inject a list that includes the bare DB name (no 8-hex suffix)
  export WTL_PRUNE_DB_LIST_CMD="printf '%s\n' 'locals_test'"
  export WTL_PRUNE_WORKTREE_LIST_CMD="printf ''"
  run bash "$BATS_TEST_DIRNAME/../libexec/db-prune"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Would drop: locals_test"* ]]
}

@test "db-prune --apply: applies drops (uses injected list, no real PG)" {
  setup_prune_env
  # Override _drop_db by providing a fake dropdb on PATH
  local fake_bin; fake_bin="$(mktemp -d)"
  cat > "$fake_bin/dropdb" <<'FAKE'
#!/usr/bin/env bash
echo "fake-dropped: $*"
FAKE
  chmod +x "$fake_bin/dropdb"
  run env PATH="$fake_bin:$PATH" bash "$BATS_TEST_DIRNAME/../libexec/db-prune" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dropping: locals_test_${ORPHAN_ID}"* ]]
  [[ "$output" == *"dropped=1"* ]]
  rm -rf "$fake_bin"
}

@test "db-prune exits 0 on --help" {
  run bash "$BATS_TEST_DIRNAME/../libexec/db-prune" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "db-prune rejects unknown args" {
  run bash "$BATS_TEST_DIRNAME/../libexec/db-prune" --bogus
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# wtl_id_for_path lib helper (derive.sh)
# ---------------------------------------------------------------------------

@test "wtl_id_for_path returns 8-hex string matching sha256[0:8] of path" {
  . "$BATS_TEST_DIRNAME/../lib/derive.sh"
  path="/some/stable/path"
  result="$(wtl_id_for_path "$path")"
  expected="$(printf '%s' "$path" | shasum -a 256 | cut -c1-8)"
  [ "$result" = "$expected" ]
  [[ "$result" =~ ^[0-9a-f]{8}$ ]]
}
