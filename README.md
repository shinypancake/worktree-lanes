# worktree-lanes

Per-worktree/lane dev+test isolation CLI for multi-worktree development.

## Installation

```bash
brew install shinypancake/tap/worktree-lanes
```

## Usage

```
worktree env [--shell|--json|--plain] [--check-ports] [--infra-mode=isolated|shared]
worktree <subcommand> [args]
```

## Configuration

Add a `worktree.config` file at your repo root:

```bash
WTL_PROJECT=myproject
WTL_ENV_PREFIX=MYPROJECT
WTL_MAIN_BACKEND_PORT=3000
WTL_MAIN_FRONTEND_PORT=5173
WTL_MAIN_POSTGRES_PORT=5432
WTL_MAIN_REDIS_PORT=6379
WTL_MAIN_MAILHOG_UI_PORT=8025
WTL_MAIN_MAILHOG_SMTP_PORT=1025
WTL_DB_USER=myproject
WTL_DB_PASSWORD=myproject_password
WTL_SERVICES="backend frontend postgres redis mailhog"
WTL_HAS_FRONTEND=1
WTL_HAS_SIDEKIQ=1
WTL_HAS_MAILHOG=1
WTL_HAS_WEBAUTHN=0
```
