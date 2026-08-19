#!/usr/bin/env bash
# Deux "Start init" avec la même graine doivent produire le même état.
# Ce contrôle ne dépend d'aucun golden ni d'aucune base de données.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SEED="${SEED:-424242}"

init_une_fois() {
  local work="$1"
  preparer_workdir "$work" "$SEED" ""
  moteur "$work" init > "$work/init.log" 2>&1
  moteur "$work" dumpState "$work/dump.txt"
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
