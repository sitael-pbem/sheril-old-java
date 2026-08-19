#!/usr/bin/env bash
# Rejoue deux fois le même scénario, dans deux répertoires de travail
# distincts, et compare leurs dumps directement entre eux. Ne touche jamais
# au golden versionné ni à git : ce contrôle atteste du déterminisme du
# moteur, pas de la conformité à une référence. Peu importe que
# run-scenario.sh échoue sur une comparaison au golden ou sur une assertion,
# seuls les dumps bruts qu'il écrit dans le répertoire de travail nous
# intéressent ici (run-scenario.sh:$WORK/dump-tour-<n>.txt, écrit avant tout
# contrôle golden/assertions/XML).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SCENARIO="${1:?usage: check-determinisme.sh <scenario>}"
TOURS="$(propriete "$REPO/test/scenarios/$SCENARIO/scenario.properties" TOURS)"

capturer() {
  local workdir="$1"
  rm -rf "$workdir"
  "$REPO/test/harness/run-scenario.sh" "$SCENARIO" --workdir "$workdir" > /dev/null 2>&1 || true
}

capturer "$REPO/test/work/det-a"
capturer "$REPO/test/work/det-b"

ECHECS=0
for n in $(seq 1 "$TOURS"); do
  a="$REPO/test/work/det-a/dump-tour-$n.txt"
  b="$REPO/test/work/det-b/dump-tour-$n.txt"
  if [ ! -f "$a" ] || [ ! -f "$b" ]; then
    echo "ECHEC: dump manquant pour le tour $n (run-scenario.sh a-t-il échoué avant de l'écrire ?)" >&2
    ECHECS=$((ECHECS+1))
    continue
  fi
  if ! /usr/bin/diff -u "$a" "$b" > "$REPO/test/work/det-diff-$n.txt"; then
    echo "ECHEC: le tour $n n'est pas reproductible" >&2
    head -40 "$REPO/test/work/det-diff-$n.txt" >&2
    ECHECS=$((ECHECS+1))
  fi
done

test "$ECHECS" = "0" || exit 1
echo "OK: $SCENARIO est reproductible sur $TOURS tour(s)"
