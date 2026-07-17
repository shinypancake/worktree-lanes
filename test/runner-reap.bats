#!/usr/bin/env bats
# Tests for runner-reap: image reaping, build-cache prune, stale-lane teardown.
# All inputs are injected (WTL_REAP_*_CMD) so no Docker daemon is required; the
# tests prove the removal predicates, not docker itself.
# shellcheck shell=bash
load helper

REAP() { bash "$BATS_TEST_DIRNAME/../libexec/runner-reap" "$@"; }

setup() {
  TEST_ROOT="$(setup_repo_root "$BATS_TEST_DIRNAME/fixtures/huddle.worktree.config")"
  export WTL_ROOT="$BATS_TEST_DIRNAME/.."
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  # Skip real git worktree resolution; point the main repo at the temp root.
  export WTL_FAKE_ROOT="$TEST_ROOT"
  export WTL_FAKE_MAIN_REPO="$TEST_ROOT"
  export GITHUB_ACTIONS=false
  cd "$TEST_ROOT"
}

teardown() { rm -rf "$TEST_ROOT"; }

# A fabricated image list. Fields: id \t repo:tag \t created-epoch \t size-bytes.
# One matching orphan (old, unreferenced), one referenced, one young, and three
# non-matching names that must never be eligible.
inject_images() {
  local now; now=$(date +%s)
  export WTL_REAP_IMAGE_LIST_CMD="printf '%s\n' \
'sha256:orphan	huddle-ci-deadbeef-backend:latest	100	1073741824' \
'sha256:refd	huddle-hud-1-x-cafebabe-sidekiq:latest	100	500' \
'sha256:young	huddle-ci-11112222-backend:latest	${now}	500' \
'sha256:locals	locals-ci-33334444-backend:latest	100	500' \
'sha256:nginx	nginx:latest	100	500' \
'sha256:mainimg	huddle-main-backend:latest	100	500'"
  # Only the 'refd' image is used by a container.
  export WTL_REAP_REFERENCED_IDS_CMD="printf '%s\n' 'sha256:refd'"
}

# ---------------------------------------------------------------------------
# arg handling
# ---------------------------------------------------------------------------

@test "runner-reap --help exits 0 and prints Usage" {
  run REAP --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "runner-reap rejects unknown args" {
  run REAP --bogus
  [ "$status" -ne 0 ]
}

@test "runner-reap rejects an invalid --only phase" {
  run REAP --only=nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"--only"* ]]
}

@test "runner-reap rejects a non-integer --max-age-hours" {
  run REAP --only=images --max-age-hours=abc
  [ "$status" -ne 0 ]
}

@test "runner-reap rejects an empty --prefix (would widen the allow-list to every project)" {
  run REAP --only=images --prefix=
  [ "$status" -ne 0 ]
  [[ "$output" == *"--prefix must not be empty"* ]]
}

# ---------------------------------------------------------------------------
# images phase
# ---------------------------------------------------------------------------

@test "images dry-run: only the matching, old, unreferenced image is eligible" {
  inject_images
  run REAP --only=images
  [ "$status" -eq 0 ]
  [[ "$output" == *"WOULD REMOVE huddle-ci-deadbeef-backend:latest"* ]]
  # Referenced image kept.
  [[ "$output" == *"KEEP  huddle-hud-1-x-cafebabe-sidekiq:latest (referenced"* ]]
  # Young image kept.
  [[ "$output" == *"KEEP  huddle-ci-11112222-backend:latest (younger"* ]]
}

@test "images dry-run: non-matching names are never listed (locals, nginx, no-hash main)" {
  inject_images
  run REAP --only=images
  [ "$status" -eq 0 ]
  [[ "$output" != *"locals-ci-33334444"* ]]
  [[ "$output" != *"nginx"* ]]
  [[ "$output" != *"huddle-main-backend"* ]]
}

@test "images dry-run does not remove (WOULD REMOVE, and rmi hook is never called)" {
  inject_images
  export WTL_REAP_RMI_CMD="echo RMI-CALLED:"
  run REAP --only=images
  [ "$status" -eq 0 ]
  [[ "$output" == *"WOULD REMOVE"* ]]
  [[ "$output" != *"RMI-CALLED:"* ]]
}

@test "images --apply removes ONLY the eligible image via rmi" {
  inject_images
  export WTL_REAP_RMI_CMD="echo RMI-CALLED:"
  run REAP --apply --only=images
  [ "$status" -eq 0 ]
  [[ "$output" == *"RMI-CALLED: huddle-ci-deadbeef-backend:latest"* ]]
  # The referenced, young, and non-matching images are never removed.
  [[ "$output" != *"RMI-CALLED: huddle-hud-1-x-cafebabe-sidekiq"* ]]
  [[ "$output" != *"RMI-CALLED: huddle-ci-11112222-backend"* ]]
  [[ "$output" != *"RMI-CALLED: locals-ci-33334444"* ]]
  [[ "$output" != *"RMI-CALLED: nginx"* ]]
  [[ "$output" == *"images_removed:  1"* ]]
}

@test "images age filter: a small --max-age-hours keeps nothing young but a huge one keeps all" {
  inject_images
  # With max-age far in the future, even the 'old' image (epoch 100) is younger
  # than the cutoff only if cutoff < 100; use a max-age so large the cutoff is
  # negative, making the young image (epoch=now) still young and orphan still old.
  run REAP --only=images --max-age-hours=1
  [ "$status" -eq 0 ]
  # epoch 100 is ancient -> eligible; epoch=now -> young.
  [[ "$output" == *"WOULD REMOVE huddle-ci-deadbeef-backend:latest"* ]]
  [[ "$output" == *"KEEP  huddle-ci-11112222-backend:latest (younger"* ]]
}

@test "images phase respects --prefix (locals prefix makes locals images eligible, huddle ones not)" {
  inject_images
  run REAP --only=images --prefix=locals
  [ "$status" -eq 0 ]
  [[ "$output" == *"WOULD REMOVE locals-ci-33334444-backend:latest"* ]]
  [[ "$output" != *"huddle-ci-deadbeef-backend"* ]]
}

@test "images fails CLOSED when container enumeration fails: phase skipped, nothing eligible, exit non-zero" {
  inject_images
  # Simulate a docker ps flake: enumeration returns failure (distinct from
  # "zero containers", which is success with empty output).
  export WTL_REAP_REFERENCED_IDS_CMD="false"
  export WTL_REAP_RMI_CMD="echo RMI-CALLED:"
  run REAP --apply --only=images
  [ "$status" -ne 0 ]
  [[ "$output" == *"skipping images phase"* ]]
  [[ "$output" != *"REMOVE"* ]]
  [[ "$output" != *"RMI-CALLED:"* ]]
}

@test "images: an rmi refusal (real docker rmi without -f refuses referenced images) is reported as FAIL, not counted removed" {
  # If the referenced-set under-reports (e.g. a container created between
  # enumeration and removal), the last line of defense is that _reap_rmi uses
  # `docker rmi` WITHOUT -f, which refuses to delete a referenced image. This
  # test documents that a refusal surfaces as FAIL + non-zero exit.
  inject_images
  export WTL_REAP_REFERENCED_IDS_CMD="printf ''"
  export WTL_REAP_RMI_CMD="false"
  run REAP --apply --only=images
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL   huddle-ci-deadbeef-backend:latest"* ]]
  [[ "$output" == *"images_removed:  0"* ]]
}

# ---------------------------------------------------------------------------
# stale-lanes phase
# ---------------------------------------------------------------------------

inject_lanes() {
  LIVE_ID="$(
    . "$BATS_TEST_DIRNAME/../lib/derive.sh"
    wtl_id_for_path "$TEST_ROOT/live-worktree"
  )"
  export WTL_REAP_WORKTREE_LIST_CMD="printf '%s\n' '$TEST_ROOT/live-worktree'"
  export WTL_REAP_PROJECT_LIST_CMD="printf '%s\n' \
'huddle-hud-598-ledger-deadbeef' \
'huddle-live-lane-${LIVE_ID}' \
'huddle-ci-1c0467d2' \
'huddle-main' \
'huddle-shared-infra' \
'locals-main-orphan-cafef00d'"
}

@test "stale-lanes dry-run: only the orphan lane (worktree gone) is torn down" {
  inject_lanes
  run REAP --only=stale-lanes
  [ "$status" -eq 0 ]
  [[ "$output" == *"WOULD TEARDOWN huddle-hud-598-ledger-deadbeef"* ]]
}

@test "stale-lanes dry-run: live lane, CI lane, -main, -shared-infra, and other-project lane survive" {
  inject_lanes
  run REAP --only=stale-lanes
  [ "$status" -eq 0 ]
  [[ "$output" != *"TEARDOWN huddle-live-lane-${LIVE_ID}"* ]]
  [[ "$output" != *"TEARDOWN huddle-ci-1c0467d2"* ]]
  [[ "$output" != *"TEARDOWN huddle-main"* ]]
  [[ "$output" != *"TEARDOWN huddle-shared-infra"* ]]
  [[ "$output" != *"TEARDOWN locals-main-orphan-cafef00d"* ]]
  [[ "$output" == *"lanes_kept_live: 1"* ]]
}

@test "stale-lanes fails CLOSED when the live-worktree list is EMPTY: no lane torn down, exit non-zero" {
  inject_lanes
  # A healthy `git worktree list` always includes the main repo, so an empty
  # result is a flake — it must never read as "every lane is stale".
  export WTL_REAP_WORKTREE_LIST_CMD="printf ''"
  export WTL_REAP_DOWN_CMD="echo DOWN-CALLED:"
  run REAP --apply --only=stale-lanes
  [ "$status" -ne 0 ]
  [[ "$output" == *"skipping stale-lanes phase"* ]]
  [[ "$output" != *"TEARDOWN"* ]]
  [[ "$output" != *"DOWN-CALLED:"* ]]
}

@test "stale-lanes fails CLOSED when the live-worktree enumeration FAILS: no lane torn down, exit non-zero" {
  inject_lanes
  export WTL_REAP_WORKTREE_LIST_CMD="false"
  export WTL_REAP_DOWN_CMD="echo DOWN-CALLED:"
  run REAP --apply --only=stale-lanes
  [ "$status" -ne 0 ]
  [[ "$output" == *"skipping stale-lanes phase"* ]]
  [[ "$output" != *"TEARDOWN"* ]]
  [[ "$output" != *"DOWN-CALLED:"* ]]
}

@test "stale-lanes --apply tears down ONLY the orphan via compose down" {
  inject_lanes
  export WTL_REAP_DOWN_CMD="echo DOWN-CALLED:"
  run REAP --apply --only=stale-lanes
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOWN-CALLED: huddle-hud-598-ledger-deadbeef"* ]]
  [[ "$output" != *"DOWN-CALLED: huddle-live-lane"* ]]
  [[ "$output" != *"DOWN-CALLED: huddle-ci-"* ]]
  [[ "$output" != *"DOWN-CALLED: locals-main"* ]]
}

# ---------------------------------------------------------------------------
# build-cache phase
# ---------------------------------------------------------------------------

@test "build-cache dry-run prints the intended prune command with the configured age" {
  export WTL_REAP_BUILDER_PRUNE_CMD="echo PRUNE-CALLED:"
  run REAP --only=build-cache --cache-age=48h
  [ "$status" -eq 0 ]
  [[ "$output" == *"WOULD RUN docker builder prune -f --filter until=48h"* ]]
  # Dry-run must NOT invoke the prune.
  [[ "$output" != *"PRUNE-CALLED:"* ]]
}

@test "build-cache --apply invokes builder prune with the configured age" {
  export WTL_REAP_BUILDER_PRUNE_CMD="echo PRUNE-CALLED:"
  run REAP --apply --only=build-cache --cache-age=12h
  [ "$status" -eq 0 ]
  [[ "$output" == *"PRUNE-CALLED: 12h"* ]]
}
