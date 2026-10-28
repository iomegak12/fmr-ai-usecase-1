#!/usr/bin/env bash
# Usage: scripts/restore.sh goal_db|transaction_db FILE
#
# Restores a pg_dump custom-format file (from scripts/backup.sh) into a
# database of the running root Compose stack. This REPLACES the database's
# current contents: pg_restore --clean --if-exists --single-transaction, so a
# failed restore leaves the database unchanged. The file must be a backup of
# that same database; a dump of the other database is refused.
#
# The database's own service (goal-service or transaction-service) is stopped
# for the restore and started again afterwards, even if the restore fails.
# Restoring one database does not roll back the other; restore both from the
# same day to keep goal balances and transaction history consistent.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
[ $# -eq 2 ] || usage_error "name a database and a backup file"
db=$1
file=$2
case $db in
goal_db) app=goal-service ;;
transaction_db) app=transaction-service ;;
*) usage_error "unknown database '$db' (expected goal_db or transaction_db)" ;;
esac
[ -f "$file" ] || die "backup file not found: $file"
service=${db%_db}-db
compose=(docker compose --progress quiet -f "$(host_path "$COMPOSE_FILE_ROOT")")
temp=/tmp/kalash-restore.dump
[ -n "$("${compose[@]}" ps --status running -q "$service")" ] ||
  die "$service is not running; start the stack with 'make up'"

restart_app() {
  info "starting $app"
  "${compose[@]}" start "$app"
}

info "$db: copying $file into $service"
"${compose[@]}" cp "$(host_path "$file")" "$service:$temp"
discard_copy() { "${compose[@]}" exec -T "$service" rm -f "$temp"; }
if ! listing=$("${compose[@]}" exec -T "$service" pg_restore --list "$temp" 2>/dev/null); then
  discard_copy
  die "$file is not a pg_dump custom-format backup"
fi
# Refuse a dump of the other database, which would add its tables here.
target_db=$("${compose[@]}" exec -T "$service" printenv POSTGRES_DB)
target_db=${target_db%$'\r'}
source_db=unknown
if [[ $listing =~ dbname:\ ([^[:space:]]+) ]]; then source_db=${BASH_REMATCH[1]}; fi
if [ "$source_db" != "$target_db" ]; then
  discard_copy
  die "$file is a backup of '$source_db', not '$target_db'"
fi

info "stopping $app for the restore"
"${compose[@]}" stop "$app"
trap restart_app EXIT
info "$db: restoring (replaces the current contents)"
"${compose[@]}" exec -T "$service" sh -c \
  "pg_restore -U \$POSTGRES_USER -d \$POSTGRES_DB --clean --if-exists --single-transaction $temp; s=\$?; rm -f $temp; exit \$s"
info "$db: restored from $file"
