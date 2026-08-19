#!/usr/bin/env bash
# Rejoue deux fois le même scénario, dans deux répertoires de travail
# distincts, et compare leurs dumps ET leurs rapports XML directement entre
# eux. Ne touche jamais au golden versionné ni à git : ce contrôle atteste
# du déterminisme du moteur, pas de la conformité à une référence. Peu
# importe que run-scenario.sh échoue sur une comparaison au golden ou sur
# une assertion, seuls les artefacts bruts qu'il écrit dans le répertoire de
# travail nous intéressent ici (run-scenario.sh:$WORK/dump-tour-<n>.txt et
# $WORK/data/tour<n>/rapports/**/rapport.xml, écrits avant tout contrôle
# golden/assertions/XML).
#
# La comparaison des rapports XML a été ajoutée en ronde de correction 1 de
# la tâche 8 (SHRL-46) : le dump ne montre ni messages ni événements
# (DumpEtat n'écrit que l'état, jamais le journal), et
# DumpEtat.ecrireMarche re-trie les offres par identifiant avant écriture
# (DumpEtat.java:258-263) — la comparaison des seuls dump-tour-*.txt est
# donc structurellement aveugle à tout non-déterminisme qui ne porte que sur
# l'ordre des messages d'un rapport (cf. tête de lib.sh, angle mort de
# l'oracle). Vécu : reglerEncheresMarche() itérait une Map<OffreMarche,...>
# hachée par identité mémoire (avant sa correction, SHRL-46 task-8) sans
# qu'aucun scénario ne puisse le révéler via les seuls dumps.
#
# MÊME RÉSERVE QUE check-composants-determinisme.sh sur la portée du vert. Les
# deux répétitions tournent dans la même JVM, avec la même graine : ce script
# atteste que le moteur rejoue à l'identique dans des conditions identiques, ce
# qui est exactement ce que le harnais lui demande. Il n'atteste RIEN sur la
# portabilité d'une JVM à l'autre, le hachage d'identité par défaut de HotSpot
# étant un xorshift par thread à graine déterministe, donc reproductible d'un
# processus à l'autre de la même JVM. Ne pas lire son vert comme « aucune Map
# hachée par identité ne peut nuire ». Le critère de falsification est le même :
# deux JDK de versions ou de fournisseurs distincts, ou deux -XX:hashCode=
# différents.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SCENARIO="${1:?usage: check-determinisme.sh <scenario>}"
TOURS="$(tours_du_scenario "$REPO/test/scenarios/$SCENARIO/scenario.properties")"

# Le journal complet ($workdir.log) est la seule trace d'un arrêt dur de
# run-scenario.sh (marqueur non résolu, base indisponible, moteur qui ne
# rend pas la main) : le "|| true" avale le code de retour, pas la sortie,
# précisément pour garder cette trace lisible au lieu de forcer à rejouer le
# scénario à la main pour savoir ce qui s'est passé.
capturer() {
  local workdir="$1" log="$1.log"
  rm -rf "$workdir"
  "$REPO/test/harness/run-scenario.sh" "$SCENARIO" --workdir "$workdir" > "$log" 2>&1 || true
}

capturer "$REPO/test/work/det-a"
capturer "$REPO/test/work/det-b"

ECHECS=0
for n in $(seq 1 "$TOURS"); do
  a="$REPO/test/work/det-a/dump-tour-$n.txt"
  b="$REPO/test/work/det-b/dump-tour-$n.txt"
  manquant=0
  if [ ! -f "$a" ]; then
    echo "ECHEC: dump manquant pour le tour $n (répétition a) : cause dans $REPO/test/work/det-a.log" >&2
    manquant=1
  fi
  if [ ! -f "$b" ]; then
    echo "ECHEC: dump manquant pour le tour $n (répétition b) : cause dans $REPO/test/work/det-b.log" >&2
    manquant=1
  fi
  if [ "$manquant" = "1" ]; then
    ECHECS=$((ECHECS+1))
    continue
  fi
  if ! /usr/bin/diff -u "$a" "$b" > "$REPO/test/work/det-diff-$n.txt"; then
    echo "ECHEC: le tour $n n'est pas reproductible" >&2
    head -40 "$REPO/test/work/det-diff-$n.txt" >&2
    ECHECS=$((ECHECS+1))
  fi
done

# Comparaison des rapports XML (cf. en-tête : angle mort des seuls dumps).
# Chemins relatifs à data/, triés, pour comparer terme à terme.
XML_A="$(cd "$REPO/test/work/det-a" && /usr/bin/find data -name '*.xml' | sort)"
XML_B="$(cd "$REPO/test/work/det-b" && /usr/bin/find data -name '*.xml' | sort)"

# Garde de non-vacuité (même motif que run-scenario.sh:213-222 et
# check-composants-determinisme.sh:51-67) : un `find` sur un répertoire
# existant mais vide de résultat ne fait pas échouer le pipeline (rien à voir
# avec le chemin absent, seul cas que couvrirait pipefail), et une boucle
# `while read` sur une chaîne vide ne lit qu'une ligne vide qu'elle escamote.
# Sans cette garde, deux répétitions sans aucun rapport XML donneraient
# XML_A = XML_B = "" : zéro comparaison effectuée, ECHECS inchangé, et le
# script conclurait "reproductible" sans avoir rien comparé. Le message dit
# ce qui est réellement constaté (aucun rapport comparé), pas un problème de
# déterminisme.
#
# La garde compte les `rapport.xml`, PAS l'ensemble des `*.xml` de la liste
# comparée. Le moteur écrit aussi des `data/stats/data.xml` et des
# `data/tour<n>/stats/data.xml` : sur un déroulé réel de 05-alliances, det-a
# porte 25 XML dont 18 rapports et 7 fichiers de statistiques. Compter les 25
# rendrait la garde inopérante, un moteur qui cesserait d'écrire tout rapport
# laissant encore un compte de 7, la garde muette, et ce script concluant
# « reproductible (dumps et rapports XML) » en n'ayant comparé que des stats.
# La comparaison, elle, reste sur l'ensemble des XML : les stats sont une
# couverture supplémentaire gratuite, ce n'est que le compteur de la garde qui
# doit porter sur ce que le message promet.
n_rapports_a="$(cd "$REPO/test/work/det-a" && /usr/bin/find data -name 'rapport.xml' | /usr/bin/wc -l | tr -d ' ')"
if [ "$n_rapports_a" -eq 0 ]; then
  echo "ECHEC: aucun rapport.xml trouvé dans $REPO/test/work/det-a, la comparaison des rapports n'a rien comparé (cause dans $REPO/test/work/det-a.log)" >&2
  ECHECS=$((ECHECS+1))
elif [ "$XML_A" != "$XML_B" ]; then
  echo "ECHEC: la liste des rapports XML produits diffère entre les deux répétitions" >&2
  ECHECS=$((ECHECS+1))
else
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    a="$REPO/test/work/det-a/$rel"
    b="$REPO/test/work/det-b/$rel"
    diffname="$REPO/test/work/det-diff-xml-$(echo "$rel" | tr '/' '_').txt"
    if ! /usr/bin/diff -u "$a" "$b" > "$diffname"; then
      echo "ECHEC: le rapport $rel n'est pas reproductible" >&2
      head -40 "$diffname" >&2
      ECHECS=$((ECHECS+1))
    fi
  done <<< "$XML_A"
fi

test "$ECHECS" = "0" || exit 1
echo "OK: $SCENARIO est reproductible sur $TOURS tour(s) (dumps et rapports XML)"
