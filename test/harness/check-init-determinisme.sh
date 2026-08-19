#!/usr/bin/env bash
# Deux "Start init" avec la même graine doivent produire le même état.
# Ce contrôle ne dépend d'aucun golden ni d'aucune base de données.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED="${SEED:-424242}"
DB_HOST="${DB_HOST:-127.0.0.1:3311}"

init_une_fois() {
  local work="$1"
  rm -rf "$work"
  mkdir -p "$work/data/commun" "$work/php/rapports" "$work/php/stats"
  cp -R "$REPO/data/fichiers" "$work/data/fichiers"
  echo "0" > "$work/data/commun/tour.txt"
  {
    sed -e 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' \
        -e "s|^DATABASE_HOST.*|DATABASE_HOST = $DB_HOST|" \
        "$REPO/config.properties.sample"
    echo ""
    echo "RANDOM_SEED = $SEED"
  } > "$work/config.properties"
  ( cd "$work" && java -cp "$REPO/sheril.jar" Start init > init.log 2>&1 )
  ( cd "$work" && java -cp "$REPO/sheril.jar" Start dumpState dump.txt )
}

init_une_fois "$REPO/test/work/init-a"
init_une_fois "$REPO/test/work/init-b"

if /usr/bin/diff -u "$REPO/test/work/init-a/dump.txt" "$REPO/test/work/init-b/dump.txt" > "$REPO/test/work/init-diff.txt"; then
  echo "OK: deux init avec la graine $SEED donnent le même état"
else
  echo "ECHEC: les deux init divergent, extrait du diff:"
  head -40 "$REPO/test/work/init-diff.txt"
  exit 1
fi
