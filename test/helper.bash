# shellcheck shell=bash
setup_repo_root() {            # $1 = config fixture path; creates a fake worktree
  WTL_TEST_TMP="$(mktemp -d)"
  git -C "$WTL_TEST_TMP" init -q
  cp "$1" "$WTL_TEST_TMP/worktree.config"
  echo "$WTL_TEST_TMP"
}
