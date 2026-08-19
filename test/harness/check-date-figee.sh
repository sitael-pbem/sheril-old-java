#!/usr/bin/env bash
# Quand DATE_FIGEE est présente dans config.properties, Utile.getDateRapport
# doit la retourner telle quelle. Quand elle est absente, la date du jour.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO/test/work/date-figee"
rm -rf "$WORK" && mkdir -p "$WORK"

appel() {
  ( cd "$WORK" && echo 'System.out.println(zIgzAg.jeu.oceane.Utile.getDateRapport());' \
      | jshell --class-path "$REPO/sheril.jar" -s - 2>/dev/null | tr -d '\r' | grep -E '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' )
}

sed 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' "$REPO/config.properties.sample" > "$WORK/config.properties"
# || true sur les deux appels : appel() se termine par un grep de forme, et
# sous set -e -o pipefail un grep sans correspondance fait avorter le script
# AVANT le test qui suit, donc sans jamais afficher son message ECHEC. Le
# contrôle échouait alors sur une sortie muette, en désignant la mauvaise
# cause. Neutraliser le code de retour ici rend la main au test, qui affiche
# la valeur obtenue (vide) et ce qui était attendu.
sans=$(appel || true)
attendu_sans=$(date +%d/%m/%Y)
test "$sans" = "$attendu_sans" || { echo "ECHEC: sans DATE_FIGEE, obtenu '$sans', attendu '$attendu_sans'"; exit 1; }

printf '\nDATE_FIGEE = 01/01/2000\n' >> "$WORK/config.properties"
avec=$(appel || true)
test "$avec" = "01/01/2000" || { echo "ECHEC: avec DATE_FIGEE, obtenu '$avec', attendu '01/01/2000'"; exit 1; }

echo "OK: DATE_FIGEE respectée, et absente le comportement est inchangé"
