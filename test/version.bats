load helper

@test "worktree version prints the VERSION file contents" {
  run "$BATS_TEST_DIRNAME/../bin/worktree" version
  [ "$status" -eq 0 ]
  expected="$(cat "$BATS_TEST_DIRNAME/../VERSION")"
  [ "$output" = "$expected" ]
}

@test "worktree version falls back to 'unknown' when VERSION file is absent" {
  tmproot="$(mktemp -d)"
  mkdir -p "$tmproot/bin" "$tmproot/lib" "$tmproot/libexec"
  cp "$BATS_TEST_DIRNAME/../bin/worktree" "$tmproot/bin/worktree"
  run "$tmproot/bin/worktree" version
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

@test "db-drop errors clearly when dropdb is not on PATH (non-dryrun)" {
  root="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/locals.worktree.config")"
  cd "$root"
  # Build a controlled PATH with symlinks to all tools the script needs,
  # explicitly excluding dropdb/psql, so the "not found on PATH" guard fires
  # even on runners that have postgres-client pre-installed.
  fake_bin="$(mktemp -d)"
  for tool in env bash sh dirname readlink id basename tr awk; do
    found="$(command -v "$tool" 2>/dev/null || true)"
    [ -n "$found" ] && ln -sf "$found" "$fake_bin/$tool"
  done
  # Portable hash: symlink whichever of sha256sum / shasum is available
  if command -v sha256sum >/dev/null 2>&1; then
    ln -sf "$(command -v sha256sum)" "$fake_bin/sha256sum"
  fi
  if command -v shasum >/dev/null 2>&1; then
    ln -sf "$(command -v shasum)" "$fake_bin/shasum"
  fi
  # WTL_FAKE_MAIN_REPO skips git worktree list (git therefore not needed on PATH)
  run env "PATH=$fake_bin" \
    WTL_FAKE_ROOT="$root" \
    WTL_FAKE_MAIN_REPO="$root" \
    GITHUB_ACTIONS=false \
    "$BATS_TEST_DIRNAME/../bin/worktree" db-drop
  rm -rf "$fake_bin"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dropdb"* ]] && [[ "$output" == *"not found on PATH"* ]]
}
