#!/usr/bin/env bats
# Structural tests for libexec/validate-parallel: confirm it references the
# parameterized vars rather than hard-coded Huddle paths.

VALIDATE_PARALLEL="$BATS_TEST_DIRNAME/../libexec/validate-parallel"

@test "validate-parallel references \${WTL_VALIDATE_SMOKE_SPEC} not hard-coded spec path" {
  # Must contain the variable reference
  grep -q '\${WTL_VALIDATE_SMOKE_SPEC' "$VALIDATE_PARALLEL"
  # Must NOT contain the bare hard-coded path in a worktree test-backend call
  run grep 'worktree test-backend spec/requests/api/v1/health_spec.rb' "$VALIDATE_PARALLEL"
  [ "$status" -ne 0 ]
}

@test "validate-parallel gates doctor step on WTL_VALIDATE_DOCTOR" {
  grep -q 'WTL_VALIDATE_DOCTOR' "$VALIDATE_PARALLEL"
  grep -q 'Skipping doctor step' "$VALIDATE_PARALLEL"
}
