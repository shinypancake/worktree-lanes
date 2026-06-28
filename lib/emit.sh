# shellcheck shell=bash

wtl_emit() {
  local mode="shell"
  local check_ports=0
  local infra_mode_override=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --shell) mode="shell" ;;
      --json)  mode="json" ;;
      --plain) mode="plain" ;;
      --check-ports) check_ports=1 ;;
      --infra-mode=*) infra_mode_override="${1#*=}" ;;
      *)
        echo "worktree env: unknown arg: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  # Apply infra-mode override if given
  if [ -n "$infra_mode_override" ]; then
    WTL_INFRA_MODE="$infra_mode_override"
    if [ "$WTL_INFRA_MODE" = "shared" ]; then
      WTL_INFRA_DB_HOST="$WTL_SHARED_DB_HOST"
      WTL_INFRA_DB_PORT="$WTL_SHARED_POSTGRES_PORT"
      WTL_INFRA_REDIS_HOST="$WTL_SHARED_REDIS_HOST"
      WTL_INFRA_REDIS_PORT="$WTL_SHARED_REDIS_PORT"
      WTL_INFRA_SMTP_HOST="$WTL_SHARED_DB_HOST"
      WTL_INFRA_SMTP_PORT="$WTL_SHARED_MAILHOG_SMTP_PORT"
    else
      WTL_INFRA_DB_HOST="postgres"
      WTL_INFRA_DB_PORT=5432
      WTL_INFRA_REDIS_HOST="redis"
      WTL_INFRA_REDIS_PORT=6379
      WTL_INFRA_SMTP_HOST="mailhog"
      WTL_INFRA_SMTP_PORT=1025
    fi
    WTL_DB_HOST="$WTL_INFRA_DB_HOST"
    WTL_DB_TCP_PORT="$WTL_INFRA_DB_PORT"
    WTL_REDIS_HOST="$WTL_INFRA_REDIS_HOST"
    WTL_REDIS_TCP_PORT="$WTL_INFRA_REDIS_PORT"
    WTL_SMTP_HOST="$WTL_INFRA_SMTP_HOST"
    WTL_SMTP_TCP_PORT="$WTL_INFRA_SMTP_PORT"
  fi

  # Port conflict check
  if [ "$check_ports" -eq 1 ]; then
    local conflict=0
    local p
    # shellcheck disable=SC2153  # WTL_REDIS_PORT is correct (not a misspelling of WTL_REDIS_HOST)
    for p in "$WTL_BACKEND_PORT" "$WTL_FRONTEND_PORT" "$WTL_MAILHOG_UI_PORT" "$WTL_MAILHOG_SMTP_PORT" "$WTL_POSTGRES_PORT" "$WTL_REDIS_PORT"; do
      if _wtl_port_in_use "$p"; then
        echo "Port in use: $p" >&2
        conflict=1
      fi
    done
    [ "$conflict" -eq 0 ] || return 2
  fi

  local pfx="$WTL_CFG_PREFIX"

  # Build the key-value list in canonical key order (mirrors the derivation order).
  # Bare keys (WORKTREE_ID, COMPOSE_FILE, etc.) are emitted as-is.
  # Prefixed keys (${PREFIX}_*) are emitted as prefixed + neutral (WTL_*) pairs.
  local keys
  keys=(
    WORKTREE_ID            "$WTL_WORKTREE_ID"
    WORKTREE_NAME          "$WTL_WORKTREE_NAME"
    WORKTREE_ROOT          "$WTL_WORKTREE_ROOT"
    MAIN_REPO              "$WTL_MAIN_REPO"
    CI_LANE_KEY            "$WTL_CI_LANE_KEY"
    IS_MAIN_WORKTREE       "$WTL_IS_MAIN"
    COMPOSE_FILE           "$WTL_COMPOSE_FILE"
    COMPOSE_PROJECT_NAME   "$WTL_COMPOSE_PROJECT"
    "${pfx}_INFRA_MODE"    "$WTL_INFRA_MODE"
    "${pfx}_BACKEND_PORT"  "$WTL_BACKEND_PORT"
    "${pfx}_FRONTEND_PORT" "$WTL_FRONTEND_PORT"
    "${pfx}_MAILHOG_UI_PORT" "$WTL_MAILHOG_UI_PORT"
    "${pfx}_MAILHOG_SMTP_PORT" "$WTL_MAILHOG_SMTP_PORT"
    "${pfx}_POSTGRES_PORT" "$WTL_POSTGRES_PORT"
    "${pfx}_REDIS_PORT"    "$WTL_REDIS_PORT"
    "${pfx}_POSTGRES_DB"   "$WTL_POSTGRES_DB"
    "${pfx}_DEV_DB_NAME"   "$WTL_DEV_DB_NAME"
    "${pfx}_TEST_DB_NAME"  "$WTL_TEST_DB_NAME"
    "${pfx}_REDIS_DB_DEV"  "$WTL_REDIS_DB_DEV"
    "${pfx}_REDIS_DB_SIDEKIQ" "$WTL_REDIS_DB_SIDEKIQ"
    "${pfx}_REDIS_DB_TEST" "$WTL_REDIS_DB_TEST"
    "${pfx}_INFRA_DB_HOST" "$WTL_INFRA_DB_HOST"
    "${pfx}_INFRA_DB_PORT" "$WTL_INFRA_DB_PORT"
    "${pfx}_INFRA_REDIS_HOST" "$WTL_INFRA_REDIS_HOST"
    "${pfx}_INFRA_REDIS_PORT" "$WTL_INFRA_REDIS_PORT"
    "${pfx}_INFRA_SMTP_HOST" "$WTL_INFRA_SMTP_HOST"
    "${pfx}_INFRA_SMTP_PORT" "$WTL_INFRA_SMTP_PORT"
    "${pfx}_DB_HOST"       "$WTL_DB_HOST"
    "${pfx}_DB_TCP_PORT"   "$WTL_DB_TCP_PORT"
    "${pfx}_REDIS_HOST"    "$WTL_REDIS_HOST"
    "${pfx}_REDIS_TCP_PORT" "$WTL_REDIS_TCP_PORT"
    "${pfx}_SMTP_HOST"     "$WTL_SMTP_HOST"
    "${pfx}_SMTP_TCP_PORT" "$WTL_SMTP_TCP_PORT"
    "${pfx}_DB_USER"       "$WTL_DB_USER"
    "${pfx}_DB_PASSWORD"   "$WTL_DB_PASSWORD"
    "${pfx}_SHARED_INFRA_PROJECT_NAME" "$WTL_SHARED_INFRA_PROJECT_NAME"
    "${pfx}_SHARED_POSTGRES_PORT" "$WTL_SHARED_POSTGRES_PORT"
    "${pfx}_SHARED_REDIS_PORT" "$WTL_SHARED_REDIS_PORT"
    "${pfx}_SHARED_MAILHOG_SMTP_PORT" "$WTL_SHARED_MAILHOG_SMTP_PORT"
    "${pfx}_SHARED_MAILHOG_UI_PORT" "$WTL_SHARED_MAILHOG_UI_PORT"
    "${pfx}_FRONTEND_URL"  "$WTL_FRONTEND_URL"
    "${pfx}_API_BASE_URL"  "$WTL_API_BASE_URL"
    "${pfx}_WS_BASE_URL"   "$WTL_WS_BASE_URL"
    "${pfx}_MAILHOG_API_URL" "$WTL_MAILHOG_API_URL"
    "${pfx}_WEBAUTHN_RP_ORIGIN" "$WTL_WEBAUTHN_RP_ORIGIN"
    "${pfx}_WEBAUTHN_RP_ID" "$WTL_WEBAUTHN_RP_ID"
    "${pfx}_HOST_LOOPBACK" "$WTL_HOST_LOOPBACK"
    "${pfx}_CONTAINER_UID" "$WTL_CONTAINER_UID"
    "${pfx}_CONTAINER_GID" "$WTL_CONTAINER_GID"
    "${pfx}_FRONTEND_CONTAINER_UID" "$WTL_FRONTEND_CONTAINER_UID"
    "${pfx}_FRONTEND_CONTAINER_GID" "$WTL_FRONTEND_CONTAINER_GID"
    "${pfx}_FRONTEND_RUN_MODE" "$WTL_FRONTEND_RUN_MODE"
  )

  if [ "$mode" = "json" ]; then
    # JSON mode: single object with all keys (prefixed + neutral aliases interleaved)
    printf '{'
    local first=1
    local i=0
    while [ "$i" -lt "${#keys[@]}" ]; do
      local k="${keys[$i]}"
      local v="${keys[$((i + 1))]}"
      [ "$first" -eq 1 ] || printf ','
      first=0
      _wtl_emit_kv "json" "$k" "$v"
      # Emit neutral alias for prefixed keys
      if [ "${k#"${pfx}"_}" != "$k" ]; then
        local neutral_key="WTL_${k#"${pfx}"_}"
        printf ','
        _wtl_emit_kv "json" "$neutral_key" "$v"
      fi
      i=$((i + 2))
    done
    printf '}\n'
  else
    # Shell/plain mode: emit all prefixed keys first (in canonical order), then WTL_* aliases
    local i=0
    while [ "$i" -lt "${#keys[@]}" ]; do
      local k="${keys[$i]}"
      local v="${keys[$((i + 1))]}"
      _wtl_emit_kv "$mode" "$k" "$v"
      i=$((i + 2))
    done
    # Now emit neutral WTL_* aliases for all prefixed keys
    i=0
    while [ "$i" -lt "${#keys[@]}" ]; do
      local k="${keys[$i]}"
      local v="${keys[$((i + 1))]}"
      if [ "${k#"${pfx}"_}" != "$k" ]; then
        local neutral_key="WTL_${k#"${pfx}"_}"
        _wtl_emit_kv "$mode" "$neutral_key" "$v"
      fi
      i=$((i + 2))
    done
  fi
}

_wtl_emit_kv() {
  local mode="$1" k="$2" v="$3"
  case "$mode" in
    shell) printf 'export %s=%q\n' "$k" "$v" ;;
    json)  printf '"%s":"%s"' "$k" "$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\"/g')" ;;
    plain) printf '%-40s %s\n' "$k" "$v" ;;
  esac
}

_wtl_port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn "( sport = :$port )" 2>/dev/null | awk 'NR>1{found=1} END{exit(found?0:1)}'
  else
    return 1
  fi
}
