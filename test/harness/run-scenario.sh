#!/usr/bin/env bash
# Déroule un scénario de bout en bout et le confronte à ses références.
#
# Usage: run-scenario.sh <scenario> [--update-golden] [--workdir DIR]
#
# Le script ignore entièrement le contenu du scénario. Ajouter un scénario est
# un dossier sous test/scenarios/, jamais une ligne ici.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENARIO="${1:?usage: run-scenario.sh <scenario> [--update-golden] [--workdir DIR]}"
shift
UPDATE=0
WORK="$REPO/test/work/$SCENARIO"

while [ $# -gt 0 ]; do
  case "$1" in
    --update-golden) UPDATE=1 ;;
    --workdir) WORK="$2"; shift ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
  esac
  shift
done

DIR="$REPO/test/scenarios/$SCENARIO"
test -d "$DIR" || { echo "scénario inconnu: $SCENARIO" >&2; exit 2; }

SEED="$(propriete "$DIR/scenario.properties" RANDOM_SEED)"
DATE_FIGEE="$(propriete "$DIR/scenario.properties" DATE_FIGEE)"
TOURS="$(propriete "$DIR/scenario.properties" TOURS)"

echo "== $SCENARIO : graine $SEED, $TOURS tour(s), répertoire $WORK"

preparer_workdir "$WORK" "$SEED" "$DATE_FIGEE"
reinitialiser_base

echo "-- init"
moteur "$WORK" init > "$WORK/init.log" 2>&1

echo "-- setup.sql"
injecter_sql "$DIR/setup.sql"

echo "-- newRound d'inscription"
moteur "$WORK" newRound > "$WORK/round-0.log" 2>&1
moteur "$WORK" dumpState "$WORK/dump-tour-0.txt"

ECHECS=0

for n in $(seq 1 "$TOURS"); do
  ordres="$DIR/turn-$n.sql"
  if [ -f "$ordres" ]; then
    echo "-- tour $n : substitution des marqueurs"
    if ! python3 "$REPO/test/harness/resolve-markers.py" \
         "$WORK/dump-tour-$((n-1)).txt" "$ordres" > "$WORK/turn-$n.resolved.sql"; then
      echo "ECHEC: marqueurs non résolus dans $ordres" >&2
      exit 1
    fi
    injecter_sql "$WORK/turn-$n.resolved.sql"
  else
    echo "-- tour $n : aucun ordre"
  fi

  echo "-- tour $n : newRound"
  moteur "$WORK" newRound > "$WORK/round-$n.log" 2>&1
  moteur "$WORK" dumpState "$WORK/dump-tour-$n.txt"

  golden="$DIR/golden/dump-tour-$n.txt"
  if [ "$UPDATE" = "1" ]; then
    mkdir -p "$DIR/golden"
    cp "$WORK/dump-tour-$n.txt" "$golden"
    echo "-- tour $n : golden régénéré"
    continue
  fi

  if [ ! -f "$golden" ]; then
    echo "ECHEC: golden absent: $golden" >&2
    ECHECS=$((ECHECS+1))
    continue
  fi

  if /usr/bin/diff -u "$golden" "$WORK/dump-tour-$n.txt" > "$WORK/diff-tour-$n.txt"; then
    echo "-- tour $n : conforme au golden"
  else
    echo "ECHEC: tour $n diverge du golden ($(grep -c '^[+-]' "$WORK/diff-tour-$n.txt") lignes)" >&2
    head -40 "$WORK/diff-tour-$n.txt" >&2
    ECHECS=$((ECHECS+1))
  fi
done

if [ "$UPDATE" = "1" ]; then
  echo "== goldens régénérés pour $SCENARIO, relire le diff avant de committer"
  exit 0
fi

echo "-- assertions"
DERNIER="$WORK/dump-tour-$TOURS.txt"
while IFS= read -r ligne; do
  case "$ligne" in ''|\#*) continue ;; esac
  if ! grep -qxF "$ligne" "$DERNIER"; then
    echo "ECHEC assertion: $ligne" >&2
    ECHECS=$((ECHECS+1))
  fi
done < "$DIR/assertions.txt"

echo "-- structure des rapports XML"
dernier_tour_dir="$WORK/data/tour$TOURS/rapports"
if [ -d "$dernier_tour_dir" ]; then
  for xml in $(find "$dernier_tour_dir" -name '*.xml'); do
    test -s "$xml" || { echo "ECHEC: rapport XML vide: $xml" >&2; ECHECS=$((ECHECS+1)); }
    python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$xml" \
      || { echo "ECHEC: rapport XML mal formé: $xml" >&2; ECHECS=$((ECHECS+1)); }
  done
fi

if [ "$ECHECS" -gt 0 ]; then
  echo "== $SCENARIO : $ECHECS échec(s)" >&2
  exit 1
fi
echo "== $SCENARIO : OK"
