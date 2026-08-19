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

# Le journal complet ($workdir.log) est la seule trace d'un arrêt dur de
# run-scenario.sh (marqueur non résolu, base indisponible, moteur qui ne
# rend pas la main) : le "|| true" avale le code de retour, pas la sortie,
# précisément pour garder cette trace lisible au lieu de forcer à rejouer le
# scénario à la main pour savoir ce qui s'est passé.
capturer() {
  local workdir="$1" log="$1.log"
  rm -rf "$workdir"
  "$REPO/test/harness/run-scenario.sh" "$SCENARIO" --workdir "$workdir" > "$log" 2>&1 || true
}

capturer "$REPO/test/work/det-a"
capturer "$REPO/test/work/det-b"

ECHECS=0
for n in $(seq 1 "$TOURS"); do
  a="$REPO/test/work/det-a/dump-tour-$n.txt"
  b="$REPO/test/work/det-b/dump-tour-$n.txt"
  manquant=0
  if [ ! -f "$a" ]; then
    echo "ECHEC: dump manquant pour le tour $n (répétition a) : cause dans $REPO/test/work/det-a.log" >&2
    manquant=1
  fi
  if [ ! -f "$b" ]; then
    echo "ECHEC: dump manquant pour le tour $n (répétition b) : cause dans $REPO/test/work/det-b.log" >&2
    manquant=1
  fi
  if [ "$manquant" = "1" ]; then
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
