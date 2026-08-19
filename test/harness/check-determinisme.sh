#!/usr/bin/env bash
# Rejoue deux fois le même scénario et compare les deux dumps entre eux.
# Ne consulte jamais le golden : ce contrôle atteste du déterminisme du moteur,
# pas de la conformité à une référence.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SCENARIO="${1:?usage: check-determinisme.sh <scenario>}"
TOURS="$(propriete "$REPO/test/scenarios/$SCENARIO/scenario.properties" TOURS)"

# Le golden versionne est restaure apres chaque passe. Quand le scenario n'en a
# pas encore (premier contact, avant d'avoir figé quoi que ce soit), git checkout
# echoue sur un chemin non suivi : on supprime alors le repertoire produit.
restaurer_golden() {
  git -C "$REPO" checkout -- "test/scenarios/$SCENARIO/golden" 2>/dev/null \
    || rm -rf "$REPO/test/scenarios/$SCENARIO/golden"
}

capturer() {
  local cible="$1" workdir="$2"
  rm -rf "$cible"
  "$REPO/test/harness/run-scenario.sh" "$SCENARIO" --update-golden --workdir "$workdir" > /dev/null
  cp -R "$REPO/test/scenarios/$SCENARIO/golden" "$cible"
  restaurer_golden
}

trap restaurer_golden EXIT

capturer "$REPO/test/work/golden-a" "$REPO/test/work/det-a"
capturer "$REPO/test/work/golden-b" "$REPO/test/work/det-b"

ECHECS=0
for n in $(seq 1 "$TOURS"); do
  if ! /usr/bin/diff -u "$REPO/test/work/golden-a/dump-tour-$n.txt" \
                        "$REPO/test/work/golden-b/dump-tour-$n.txt" > "$REPO/test/work/det-diff-$n.txt"; then
    echo "ECHEC: le tour $n n'est pas reproductible" >&2
    head -40 "$REPO/test/work/det-diff-$n.txt" >&2
    ECHECS=$((ECHECS+1))
  fi
done

test "$ECHECS" = "0" || exit 1
echo "OK: $SCENARIO est reproductible sur $TOURS tour(s)"
