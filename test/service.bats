#!/usr/bin/env bats
# shellcheck shell=bash
load helper

setup() {
  export WTL_ROOT="$BATS_TEST_DIRNAME/.."
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

setup_root_with_fixture() {
  local fixture="$1"
  local root
  root="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/${fixture}")"
  cd "$root"
}

@test "frontend scripts exit 0 with clear message when WTL_HAS_FRONTEND=0" {
  # Use a config without frontend
  setup_root_with_fixture "locals.worktree.config"
  # Override has_frontend to 0 for this test by creating a minimal config
  local tmpdir
  tmpdir="$(mktemp -d)"
  git -C "$tmpdir" init -q
  cat > "$tmpdir/worktree.config" <<'EOF'
WTL_PROJECT=nofrontend
WTL_ENV_PREFIX=NOFRONTEND
WTL_MAIN_BACKEND_PORT=4001
WTL_MAIN_FRONTEND_PORT=5001
WTL_MAIN_POSTGRES_PORT=5501
WTL_MAIN_REDIS_PORT=6501
WTL_HAS_FRONTEND=0
WTL_HAS_SIDEKIQ=0
EOF
  cd "$tmpdir"
  run bash "$BATS_TEST_DIRNAME/../libexec/up-frontend"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not configured"* ]]
}

@test "sidekiq scripts exit 0 with clear message when WTL_HAS_SIDEKIQ=0" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  git -C "$tmpdir" init -q
  cat > "$tmpdir/worktree.config" <<'EOF'
WTL_PROJECT=nosidekiq
WTL_ENV_PREFIX=NOSIDEKIQ
WTL_MAIN_BACKEND_PORT=4002
WTL_MAIN_FRONTEND_PORT=5002
WTL_MAIN_POSTGRES_PORT=5502
WTL_MAIN_REDIS_PORT=6502
WTL_HAS_FRONTEND=0
WTL_HAS_SIDEKIQ=0
EOF
  cd "$tmpdir"
  run bash "$BATS_TEST_DIRNAME/../libexec/up-sidekiq"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not configured"* ]]
}

@test "stop-frontend exits 0 with clear message when WTL_HAS_FRONTEND=0" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  git -C "$tmpdir" init -q
  cat > "$tmpdir/worktree.config" <<'EOF'
WTL_PROJECT=nofrontend2
WTL_ENV_PREFIX=NOFRONTEND2
WTL_MAIN_BACKEND_PORT=4003
WTL_MAIN_FRONTEND_PORT=5003
WTL_MAIN_POSTGRES_PORT=5503
WTL_MAIN_REDIS_PORT=6503
WTL_HAS_FRONTEND=0
WTL_HAS_SIDEKIQ=0
EOF
  cd "$tmpdir"
  run bash "$BATS_TEST_DIRNAME/../libexec/stop-frontend"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not configured"* ]]
}
