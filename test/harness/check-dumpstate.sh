#!/usr/bin/env bash
# Contrôle minimal de Start dumpState : la commande existe, produit un fichier
# non vide contenant les sections attendues, au format « clé = valeur ».
#
# Le dump n'est PAS trié au sens de sort(1), et ce script ne le vérifie pas : il
# est écrit dans un ordre de clé CONSTANT d'une exécution à l'autre, ce qui est
# la seule propriété dont le harnais a besoin. Un `sort -c` échouerait, l'ordre
# des positions étant numérique par composante (0_1_6 précède 0_1_14) et non
# lexicographique.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
WORK="$REPO/test/work/dumpstate"

preparer_workdir "$WORK" "" ""
# Le journal d'init est restitué en cas d'échec, sans quoi un init qui casse
# fait échouer le contrôle deux lignes plus bas, sur « dump.txt vide », ce qui
# désigne dumpState alors que la faute est en amont.
moteur "$WORK" init > "$WORK/init.log" 2>&1 \
  || { echo "ECHEC: Start init a échoué, journal ci-dessous"; cat "$WORK/init.log"; exit 1; }
moteur "$WORK" dumpState "$WORK/dump.txt"

test -s "$WORK/dump.txt" || { echo "ECHEC: dump.txt vide ou absent"; exit 1; }

for cle in "tour = " "commandant.0.nom = " "commandant.0.flottes = " "systeme."; do
  grep -q "^$cle" "$WORK/dump.txt" || { echo "ECHEC: section manquante: $cle"; exit 1; }
done

# Toute ligne non vide doit avoir la forme "cle = valeur". La clé n'est pas
# contrainte à un jeu de caractères : un nom de plan de vaisseau contient une
# espace ("Chasseur standard"), et il apparaît dans la clé
# commandant.<n>.flotte.<f>.vaisseau.<type>.
if grep -vE '^[^=]+ = ' "$WORK/dump.txt" | grep -q .; then
  echo "ECHEC: lignes hors format 'cle = valeur'"
  grep -vnE '^[^=]+ = ' "$WORK/dump.txt" | head
  exit 1
fi

# Le mode --complet est la porte de sortie de diagnostic du dump : il détaille
# les planètes et les possessions que le mode normal résume. Il n'est exercé
# par aucun scénario, puisque les goldens sont figés en mode normal. Sans ce
# second appel, ecrirePlanete, ecrirePossession et les branches détaillées de
# flotte ne seraient jamais exécutées par le harnais, et le jour où quelqu'un
# ouvre cette porte pour diagnostiquer une divergence, il découvrirait qu'elle
# est cassée depuis longtemps. Le contrôle est volontairement grossier, un
# fichier non vide et strictement plus détaillé que le mode normal.
moteur "$WORK" dumpState "$WORK/dump-complet.txt" --complet
test -s "$WORK/dump-complet.txt" || { echo "ECHEC: dump-complet.txt vide ou absent"; exit 1; }
n_normal=$(wc -l < "$WORK/dump.txt" | tr -d " ")
n_complet=$(wc -l < "$WORK/dump-complet.txt" | tr -d " ")
if [ "$n_complet" -le "$n_normal" ]; then
  echo "ECHEC: --complet rend $n_complet lignes contre $n_normal en mode normal, il devrait en rendre strictement plus"
  exit 1
fi
grep -q '^systeme\.[^ ]*\.planete\.' "$WORK/dump-complet.txt" \
  || { echo "ECHEC: --complet ne détaille aucune planète"; exit 1; }

echo "OK: $n_normal lignes en mode normal, $n_complet en --complet"
