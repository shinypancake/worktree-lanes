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
  # Build a controlled PATH: a fake_bin dir containing ONLY a sentinel that exists
  # so the PATH itself works, but dropdb/psql are absent.  Append the real PATH so
  # bash, git, awk, sha256sum, id, tr, etc. all resolve normally.
  fake_bin="$(mktemp -d)"
  # WTL_FAKE_MAIN_REPO skips git worktree list (no git call needed for IS_MAIN detection)
  run env "PATH=$fake_bin:$PATH" \
    WTL_FAKE_ROOT="$root" \
    WTL_FAKE_MAIN_REPO="$root" \
    "$BATS_TEST_DIRNAME/../bin/worktree" db-drop
  rm -rf "$fake_bin"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dropdb"* ]] && [[ "$output" == *"not found on PATH"* ]]
}
