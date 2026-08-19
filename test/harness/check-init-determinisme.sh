#!/usr/bin/env bash
# Deux "Start init" avec la même graine doivent produire le même état.
# Ce contrôle ne dépend d'aucun golden ni d'aucune base de données.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
verifier_jar
SEED="${SEED:-424242}"

init_une_fois() {
  local work="$1"
  preparer_workdir "$work" "$SEED" ""
  moteur_journalise "$work" "$work/init.log" init
  moteur "$work" dumpState "$work/dump.txt"
}

init_une_fois "$REPO/test/work/init-a"
init_une_fois "$REPO/test/work/init-b"

# Garde de non-vacuité avant le verdict. Sans elle, le contrôle se résume à un
# diff nu : deux univers dégénérés mais identiques passeraient au vert, et le
# script conclurait au déterminisme en ayant comparé deux fichiers qui ne
# décrivent rien. Un init réel rend environ 2200 lignes ; le plancher est posé
# très bas, il n'est pas là pour mesurer la taille de l'univers mais pour
# distinguer un dump d'un résidu.
PLANCHER_LIGNES=500
for cote in a b; do
  f="$REPO/test/work/init-$cote/dump.txt"
  n_lignes=$(wc -l < "$f" | tr -d ' ')
  if [ "$n_lignes" -lt "$PLANCHER_LIGNES" ]; then
    echo "ECHEC: $f ne fait que $n_lignes lignes (plancher $PLANCHER_LIGNES), l'init n'a pas produit d'univers"
    exit 1
  fi
  grep -q '^systeme\.' "$f" || { echo "ECHEC: $f ne décrit aucun système"; exit 1; }
done

if /usr/bin/diff -u "$REPO/test/work/init-a/dump.txt" "$REPO/test/work/init-b/dump.txt" > "$REPO/test/work/init-diff.txt"; then
  echo "OK: deux init avec la graine $SEED donnent le même état ($n_lignes lignes)"
else
  echo "ECHEC: les deux init divergent, extrait du diff:"
  head -40 "$REPO/test/work/init-diff.txt"
  exit 1
fi
