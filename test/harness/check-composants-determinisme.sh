#!/usr/bin/env bash
# La description des composants d'un plan doit être identique d'une JVM à l'autre.
#
# Contrôle de cohérence, pas de correctif : ComposantDeVaisseau hérite (via Produit)
# de Technologie, qui redéfinit equals/hashCode par valeur (codeDeBase, niveau).
# Les HashMap<ComposantDeVaisseau, Integer> de PlanDeVaisseau/RapportXML/DataXML
# sont donc hachées par valeur, pas par identité mémoire, et leur ordre d'itération
# est déjà déterministe (String.hashCode et Integer.hashCode sont spécifiés par le
# JDK et stables d'une machine à l'autre). Ce script l'atteste et sera câblé en CI.
#
# CE QUE SON VERT ATTESTE, ET CE QU'IL N'ATTESTE PAS. Les deux répétitions sont
# deux processus de LA MÊME JVM, même version, même fournisseur. Or sous HotSpot
# le hachage d'identité par défaut est un xorshift par thread à graine
# déterministe : deux processus de la même JVM rendent le même ordre de table
# même quand la clé n'a ni equals ni hashCode. Ce script ne peut donc PAS rougir
# pour la raison qui figure dans son titre, quelle que soit l'implémentation de
# hashCode dans Technologie. Ce qu'il atteste réellement est plus étroit et
# reste utile : la description est stable d'une exécution à l'autre, et la
# capture n'est ni vide ni tronquée (garde de non-vacuité plus bas).
# Le critère de falsification, si l'on veut vraiment tester la portabilité
# inter-JVM : deux répétitions sous deux JDK de versions ou de fournisseurs
# distincts, ou sous des -XX:hashCode= différents.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
WORK="$REPO/test/work/composants"

preparer_workdir "$WORK" 424242 ""
moteur "$WORK" init > "$WORK/init.log" 2>&1

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
# identiques à tort. Critère structurel, sans dépendre d'un nom de plan précis
# (qui peut être renommé/rééquilibré dans data/fichiers sans rapport avec le
# déterminisme testé) : on exige un nombre minimal de plans à composants
# multiples, c'est-à-dire de lignes contenant au moins un séparateur "<BR>".
# Ce sont les seules lignes pertinentes pour un test d'ordre d'itération : un
# plan à un seul composant ne peut pas révéler une permutation. Le seuil est
# volontairement bas par rapport au jeu actuel (marge), il garde contre une
# troncature, pas contre une évolution du contenu ludique.
SEUIL_MIN_COMPOSANTS_MULTIPLES=8
n_composants_multiples="$(grep -c '<BR>' "$WORK/a.txt" || true)"
if [ "${n_composants_multiples:-0}" -lt "$SEUIL_MIN_COMPOSANTS_MULTIPLES" ]; then
  echo "ECHEC: capture trop courte pour être significative ($n_composants_multiples plan(s) à composants multiples, attendu >= $SEUIL_MIN_COMPOSANTS_MULTIPLES)"
  exit 1
fi

if /usr/bin/diff -u "$WORK/a.txt" "$WORK/b.txt" > "$WORK/diff.txt"; then
  echo "OK: $(wc -l < "$WORK/a.txt") plans décrits à l'identique dans deux JVM"
else
  echo "ECHEC: la description des composants varie d'une JVM à l'autre:"
  head -20 "$WORK/diff.txt"
  exit 1
fi
