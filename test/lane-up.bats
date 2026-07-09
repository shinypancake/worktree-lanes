#!/usr/bin/env bats
# shellcheck shell=bash
load helper

@test "lane-up --detach sources the shared CI retry helper" {
  run bash -n "$BATS_TEST_DIRNAME/../libexec/lane-up"
  [ "$status" -eq 0 ]
  grep -q "ci_compose_retry.sh" "$BATS_TEST_DIRNAME/../libexec/lane-up"
  grep -q "wtl_compose_up_with_ci_retry" "$BATS_TEST_DIRNAME/../libexec/lane-up"
}
