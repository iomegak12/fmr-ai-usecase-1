#!/usr/bin/env bash
# Usage: scripts/backup.sh [goal_db|transaction_db|all ...]
#
# Backs up databases of the running root Compose stack (LLD Section 29) with
# pg_dump's custom format to BACKUP_DIR/<db>/<YYYY-MM-DD>.dump. A second backup
# on the same day replaces that day's file. Each dump is checked with
# pg_restore --list before it is kept. Dumps older than BACKUP_RETENTION_DAYS
# are then deleted. With no database, backs up both.
#
# Settings come from the environment, then the root .env:
#   BACKUP_DIR             default ./backups (relative to the repository root)
#   BACKUP_RETENTION_DAYS  default 7
# Schedule it with host cron or Task Scheduler (daily at 02:00 IST in the LLD).

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
select_projects "goal_db transaction_db" "$@"

backup_dir=$(setting BACKUP_DIR ./backups)
retention=$(setting BACKUP_RETENTION_DAYS 7)
[[ $retention =~ ^[1-9][0-9]*$ ]] || die "BACKUP_RETENTION_DAYS must be a whole number of days"
case $backup_dir in /* | [A-Za-z]:*) ;; *) backup_dir="$KALASH_ROOT/${backup_dir#./}" ;; esac
compose=(docker compose --progress quiet -f "$(host_path "$COMPOSE_FILE_ROOT")")
today=$(date +%F)
temp=/tmp/kalash-backup.dump

for db in "${PROJECTS[@]}"; do
  service=${db%_db}-db
  [ -n "$("${compose[@]}" ps --status running -q "$service")" ] ||
    die "$service is not running; start the stack with 'make up'"
  target_dir="$backup_dir/$db"
  target="$target_dir/$today.dump"
  mkdir -p "$target_dir"
  info "$db: pg_dump from $service"
  "${compose[@]}" exec -T "$service" sh -c \
    "pg_dump -U \$POSTGRES_USER -d \$POSTGRES_DB -Fc -f $temp && pg_restore --list $temp >/dev/null"
  "${compose[@]}" cp "$service:$temp" "$(host_path "$target.partial")"
  "${compose[@]}" exec -T "$service" rm -f "$temp"
  mv -f "$target.partial" "$target"
  info "$db: saved $target ($(wc -c <"$target" | tr -d ' ') bytes)"

  find "$target_dir" -maxdepth 1 -type f -name '????-??-??.dump' -mmin +$((retention * 1440)) \
    -print -delete | sed 's/^/==> removed expired backup /'
done
