#!/usr/bin/env bash
# Contrôle minimal de Start dumpState : la commande existe, produit un fichier
# non vide, trié, et contenant les sections attendues.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO/test/work/dumpstate"
DB_HOST="${DB_HOST:-127.0.0.1:3311}"

rm -rf "$WORK"
mkdir -p "$WORK/data/commun" "$WORK/php/rapports" "$WORK/php/stats"
cp -R "$REPO/data/fichiers" "$WORK/data/fichiers"
echo "0" > "$WORK/data/commun/tour.txt"
sed -e "s|^DATABASE_HOST.*|DATABASE_HOST = $DB_HOST|" \
    -e 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' \
    "$REPO/config.properties.sample" > "$WORK/config.properties"

cd "$WORK"
java -cp "$REPO/sheril.jar" Start init > init.log 2>&1
java -cp "$REPO/sheril.jar" Start dumpState dump.txt

test -s dump.txt || { echo "ECHEC: dump.txt vide ou absent"; exit 1; }

for cle in "tour = " "commandant.0.nom = " "commandant.0.flottes = " "systeme."; do
  grep -q "^$cle" dump.txt || { echo "ECHEC: section manquante: $cle"; exit 1; }
done

# Toute ligne non vide doit avoir la forme "cle = valeur". La clé n'est pas
# contrainte à un jeu de caractères : un nom de plan de vaisseau contient une
# espace ("Chasseur standard"), et il apparaît dans la clé
# commandant.<n>.flotte.<f>.vaisseau.<type>.
if grep -vE '^[^=]+ = ' dump.txt | grep -q .; then
  echo "ECHEC: lignes hors format 'cle = valeur'"
  grep -vnE '^[^=]+ = ' dump.txt | head
  exit 1
fi

echo "OK: $(wc -l < dump.txt) lignes"
