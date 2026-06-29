load helper

@test "worktree version prints the VERSION file contents" {
  run "$BATS_TEST_DIRNAME/../bin/worktree" version
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.2" ]
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
  # minimal PATH without postgres client tools; keep coreutils for the script
  run env PATH="/usr/bin:/bin" WTL_FAKE_ROOT="$root" "$BATS_TEST_DIRNAME/../bin/worktree" db-drop
  [ "$status" -ne 0 ]
  [[ "$output" == *"dropdb"* ]] && [[ "$output" == *"not found on PATH"* ]]
}
