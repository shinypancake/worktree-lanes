# shellcheck shell=bash
# shellcheck disable=SC2034  # WTL_CFG_* vars are consumed by callers (lib/derive.sh, lib/emit.sh)
wtl_find_config() {
  local dir; dir="$(pwd -P)"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/worktree.config" ] && { printf '%s\n' "$dir/worktree.config"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

wtl_load_config() {
  local cfg; cfg="$(wtl_find_config)" || {
    echo "worktree: no worktree.config found (searched up from $(pwd)). Add one at the repo root." >&2
    return 1
  }
  # shellcheck disable=SC1090
  . "$cfg"
  : "${WTL_PROJECT:?worktree.config: WTL_PROJECT is required}"
  : "${WTL_ENV_PREFIX:?worktree.config: WTL_ENV_PREFIX is required}"
  # Validate WTL_ENV_PREFIX is a safe shell identifier before it reaches wtl_getvar's eval.
  # Rejects anything with $, (, ), whitespace, or other shell-special characters that would
  # allow command substitution or expansion inside the eval "printf '%s' \"\${...}\"" call.
  if [[ ! "$WTL_ENV_PREFIX" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "worktree.config: WTL_ENV_PREFIX must be a valid shell identifier (got: $WTL_ENV_PREFIX)" >&2
    return 1
  fi
  WTL_CFG_PROJECT="$WTL_PROJECT"
  WTL_CFG_PREFIX="$WTL_ENV_PREFIX"
  WTL_CFG_DB_USER="${WTL_DB_USER:-$WTL_PROJECT}"
  WTL_CFG_DB_PASSWORD="${WTL_DB_PASSWORD:-${WTL_PROJECT}_password}"
  WTL_CFG_MAIN_BACKEND_PORT="${WTL_MAIN_BACKEND_PORT:?worktree.config: WTL_MAIN_BACKEND_PORT is required}"
  WTL_CFG_MAIN_FRONTEND_PORT="${WTL_MAIN_FRONTEND_PORT:?worktree.config: WTL_MAIN_FRONTEND_PORT is required}"
  WTL_CFG_MAIN_POSTGRES_PORT="${WTL_MAIN_POSTGRES_PORT:?worktree.config: WTL_MAIN_POSTGRES_PORT is required}"
  WTL_CFG_MAIN_REDIS_PORT="${WTL_MAIN_REDIS_PORT:?worktree.config: WTL_MAIN_REDIS_PORT is required}"
  WTL_CFG_MAIN_MAILHOG_UI_PORT="${WTL_MAIN_MAILHOG_UI_PORT:-8025}"
  WTL_CFG_MAIN_MAILHOG_SMTP_PORT="${WTL_MAIN_MAILHOG_SMTP_PORT:-1025}"
  WTL_CFG_NONMAIN_BACKEND_PORT_BASE="${WTL_NONMAIN_BACKEND_PORT_BASE:-43000}"
  WTL_CFG_NONMAIN_FRONTEND_PORT_BASE="${WTL_NONMAIN_FRONTEND_PORT_BASE:-44000}"
  WTL_CFG_NONMAIN_MAILHOG_UI_PORT_BASE="${WTL_NONMAIN_MAILHOG_UI_PORT_BASE:-45000}"
  WTL_CFG_NONMAIN_MAILHOG_SMTP_PORT_BASE="${WTL_NONMAIN_MAILHOG_SMTP_PORT_BASE:-46000}"
  WTL_CFG_NONMAIN_POSTGRES_PORT_BASE="${WTL_NONMAIN_POSTGRES_PORT_BASE:-47000}"
  WTL_CFG_NONMAIN_REDIS_PORT_BASE="${WTL_NONMAIN_REDIS_PORT_BASE:-48000}"
  WTL_CFG_SERVICES="${WTL_SERVICES:-backend postgres redis}"
  WTL_CFG_HAS_FRONTEND="${WTL_HAS_FRONTEND:-0}"
  WTL_CFG_HAS_SIDEKIQ="${WTL_HAS_SIDEKIQ:-0}"
  WTL_CFG_HAS_MAILHOG="${WTL_HAS_MAILHOG:-0}"
  WTL_CFG_HAS_WEBAUTHN="${WTL_HAS_WEBAUTHN:-0}"
  WTL_CFG_REDIS_DB_DEV="${WTL_REDIS_DB_DEV:-1}"
  WTL_CFG_REDIS_DB_SIDEKIQ="${WTL_REDIS_DB_SIDEKIQ:-2}"
  WTL_CFG_REDIS_DB_TEST="${WTL_REDIS_DB_TEST:-3}"
}
