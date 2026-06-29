load helper

@test "worktree version subcommand exits zero and matches VERSION file" {
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
