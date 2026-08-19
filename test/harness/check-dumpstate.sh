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
moteur "$WORK" init > "$WORK/init.log" 2>&1
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

echo "OK: $(wc -l < "$WORK/dump.txt") lignes"
