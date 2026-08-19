#!/usr/bin/env bash
# La description des composants d'un plan doit être identique d'une JVM à l'autre.
#
# Contrôle de cohérence, pas de correctif : ComposantDeVaisseau hérite (via Produit)
# de Technologie, qui redéfinit equals/hashCode par valeur (codeDeBase, niveau).
# Les HashMap<ComposantDeVaisseau, Integer> de PlanDeVaisseau/RapportXML/DataXML
# sont donc hachées par valeur, pas par identité mémoire, et leur ordre d'itération
# est déjà déterministe (String.hashCode et Integer.hashCode sont spécifiés par le
# JDK et stables d'une machine à l'autre). Ce script l'atteste et sera câblé en CI.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO/test/work/composants"
DB_HOST="${DB_HOST:-127.0.0.1:3311}"

rm -rf "$WORK"
mkdir -p "$WORK/data/commun" "$WORK/php/rapports" "$WORK/php/stats"
cp -R "$REPO/data/fichiers" "$WORK/data/fichiers"
echo "0" > "$WORK/data/commun/tour.txt"
{
  sed -e 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' \
      -e "s|^DATABASE_HOST.*|DATABASE_HOST = $DB_HOST|" \
      "$REPO/config.properties.sample"
  printf '\nRANDOM_SEED = 424242\n'
} > "$WORK/config.properties"
( cd "$WORK" && java -cp "$REPO/sheril.jar" Start init > init.log 2>&1 )

# Charge l'univers et imprime la description des composants de tous les plans,
# une ligne par plan. Le fichier est rejoué dans deux JVM distinctes.
cat > "$WORK/descriptions.jsh" <<'EOF'
import zIgzAg.jeu.oceane.*;
import java.util.*;
new Univers(true, "composants");
PlanDeVaisseau[] plans = Univers.listePlansDeVaisseaux();
Arrays.sort(plans, (a, b) -> a.getNom().compareTo(b.getNom()));
for (PlanDeVaisseau p : plans) System.out.println(p.getNom() + " | " + p.descriptionComposants(Locale.FRENCH));
/exit
EOF

joue() { ( cd "$WORK" && jshell --class-path "$REPO/sheril.jar" -s "$WORK/descriptions.jsh" 2>/dev/null | grep ' | ' ); }

joue > "$WORK/a.txt"
joue > "$WORK/b.txt"

test -s "$WORK/a.txt" || { echo "ECHEC: aucune description produite"; exit 1; }

# Garde de non-vacuité : une capture vide est déjà écartée ci-dessus, mais une
# capture tronquée de façon identique dans les deux JVM (ex. jshell interrompu
# après les premiers plans) resterait non vide et comparerait deux fichiers
# identiques à tort. On exige la présence des plans à composants multiples
# cités dans la spec du chantier, chacun avec au moins un séparateur "<BR>"
# (donc au moins deux composants distincts), ce qui ne peut être vrai que si
# la description a été produite en entier.
for plan in "Destroyer standard" "Croiseur standard" "Supercroiseur standard"; do
  grep -q "^$plan | .*<BR>" "$WORK/a.txt" \
    || { echo "ECHEC: capture non significative, '$plan' absent ou réduit à un seul composant"; exit 1; }
done

if /usr/bin/diff -u "$WORK/a.txt" "$WORK/b.txt" > "$WORK/diff.txt"; then
  echo "OK: $(wc -l < "$WORK/a.txt") plans décrits à l'identique dans deux JVM"
else
  echo "ECHEC: la description des composants varie d'une JVM à l'autre:"
  head -20 "$WORK/diff.txt"
  exit 1
fi
