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

@test "rejects WTL_ENV_PREFIX with shell metacharacters (injection guard)" {
  tmpdir="$(mktemp -d)"
  pwn_file="/tmp/wtl_pwn_$$"
  cat >"$tmpdir/worktree.config" <<'EOF'
WTL_PROJECT=safe
WTL_ENV_PREFIX='x$(touch /tmp/wtl_pwn_$$)'
WTL_MAIN_BACKEND_PORT=3000
WTL_MAIN_FRONTEND_PORT=5173
WTL_MAIN_POSTGRES_PORT=5432
WTL_MAIN_REDIS_PORT=6379
EOF
  cd "$tmpdir"
  run wtl_load_config
  [ "$status" -ne 0 ]
  [[ "$output" == *"valid shell identifier"* ]]
  [ ! -f "$pwn_file" ]
  rm -rf "$tmpdir"
}
