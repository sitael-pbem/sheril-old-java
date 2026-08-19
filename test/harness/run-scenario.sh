#!/usr/bin/env bash
# Déroule un scénario de bout en bout et le confronte à ses références.
#
# Usage: run-scenario.sh <scenario> [--update-golden] [--workdir DIR]
#
# Le script ignore entièrement le contenu du scénario. Ajouter un scénario est
# un dossier sous test/scenarios/, jamais une ligne ici.
#
# Numérotation des tours : dump-tour-N.txt est capturé après le newRound du
# tour N, et le tout premier newRound (inscription, avant la boucle) fait déjà
# passer le compteur interne de 0 à 1. Le dump du tour N affiche donc
# "tour = N+1", et les rapports du tour N vivent sous data/tour<N+1>/rapports.
#
# Assertions : assertions.txt (obligatoire) est vérifié contre le dump du
# dernier tour. Un assertions-tour-<n>.txt (optionnel) par tour intermédiaire
# est vérifié contre le dump de ce tour-là, dès qu'il existe. Un fichier
# d'assertions présent mais sans aucune ligne exploitable est un échec : un
# fichier vide n'assure plus rien, et le laisser passer serait exactement le
# mode "vert et vide" que ce harnais existe pour interdire. Ce contrôle
# s'applique aussi en mode --update-golden : figer un golden ne dispense pas
# de vérifier que le scénario tient encore ses promesses.
#
# Erreurs moteur : tout <m type="ERR"> dans un rapport XML d'un tour joué fait
# échouer le scénario, sauf si scenario.properties déclare
# ERREURS_TOLEREES = true (porte de sortie explicite, pour un scénario qui
# testerait délibérément un rejet d'ordre).
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
# || true : ERREURS_TOLEREES est facultative, et propriete() (lib.sh) échoue
# silencieusement sous set -e -o pipefail quand la clé est absente (grep sans
# correspondance). Connu, non retouché ici (lib.sh reste hors périmètre) ;
# neutralisé localement pour cette lecture optionnelle.
ERREURS_TOLEREES="$(propriete "$DIR/scenario.properties" ERREURS_TOLEREES || true)"

echo "== $SCENARIO : graine $SEED, $TOURS tour(s), répertoire $WORK"

ECHECS=0

# Vérifie qu'aucune ligne non vide/non commentée de $1 ne manque dans le dump
# $2, et échoue si $1 ne contient au final aucune ligne exploitable.
verifier_assertions() {
  local fichier="$1" dump="$2" total=0 ligne
  while IFS= read -r ligne; do
    case "$ligne" in ''|\#*) continue ;; esac
    total=$((total+1))
    if ! grep -qxF "$ligne" "$dump"; then
      echo "ECHEC assertion ($fichier): $ligne" >&2
      ECHECS=$((ECHECS+1))
    fi
  done < "$fichier"
  if [ "$total" -eq 0 ]; then
    echo "ECHEC: $fichier ne contient aucune assertion exploitable, il n'assure plus rien" >&2
    ECHECS=$((ECHECS+1))
  fi
}

preparer_workdir "$WORK" "$SEED" "$DATE_FIGEE"
reinitialiser_base

echo "-- init"
moteur "$WORK" init > "$WORK/init.log" 2>&1

echo "-- setup.sql"
injecter_sql "$DIR/setup.sql"

echo "-- newRound d'inscription"
moteur "$WORK" newRound > "$WORK/round-0.log" 2>&1
moteur "$WORK" dumpState "$WORK/dump-tour-0.txt"

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

  assertions_tour="$DIR/assertions-tour-$n.txt"
  if [ -f "$assertions_tour" ]; then
    verifier_assertions "$assertions_tour" "$WORK/dump-tour-$n.txt"
  fi

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
fi

echo "-- assertions (dernier tour)"
verifier_assertions "$DIR/assertions.txt" "$WORK/dump-tour-$TOURS.txt"

echo "-- rapports XML : bonne formation et absence d'erreur moteur"
for n in $(seq 1 $((TOURS+1))); do
  tour_dir="$WORK/data/tour$n/rapports"
  if [ ! -d "$tour_dir" ]; then
    echo "ECHEC: répertoire de rapports attendu absent: $tour_dir" >&2
    ECHECS=$((ECHECS+1))
    continue
  fi
  for xml in $(find "$tour_dir" -name '*.xml'); do
    test -s "$xml" || { echo "ECHEC: rapport XML vide: $xml" >&2; ECHECS=$((ECHECS+1)); }
    python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$xml" \
      || { echo "ECHEC: rapport XML mal formé: $xml" >&2; ECHECS=$((ECHECS+1)); }
    if [ "$ERREURS_TOLEREES" != "true" ] && /usr/bin/grep -q 'type="ERR"' "$xml"; then
      echo "ECHEC: erreur moteur signalée dans $xml :" >&2
      /usr/bin/grep 'type="ERR"' "$xml" >&2
      ECHECS=$((ECHECS+1))
    fi
  done
done

if [ "$ECHECS" -gt 0 ]; then
  echo "== $SCENARIO : $ECHECS échec(s)" >&2
  exit 1
fi
echo "== $SCENARIO : OK"
