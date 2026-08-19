#!/usr/bin/env bash
# Fonctions communes aux scripts du harnais.
# Aucune de ces fonctions ne connaît le contenu d'un scénario.
#
# PIÈGE À CONNAÎTRE (ronde de correction 1, SHRL-46) : dans les tables
# d'ordres qui portent une position (deplacer_flotte, changer_capitale...),
# la colonne POSX alimente en réalité la composante Y de la Position
# construite côté moteur, et POSY alimente la composante X. C'est
# ReceptionOrdres.deplacer_flotte qui construit
# "new Position(GALAXIE, POSX, POSY)", et le constructeur Position(gala, y, x)
# range son premier argument de position dans pos[0] (= Y). Le dump, lui,
# rend une position sous la forme g_y_x (Position.toString()). Pour viser une
# position lue "g_Y_X" dans un dump, écrire POSX = Y et POSY = X dans
# l'ordre SQL, jamais POSX = X. Vécu sur 01-combat : une flotte envoyée avec
# POSX = @CAPX(...)@ / POSY = @CAPY(...)@ atterrit sur une position qui n'existe
# pas, silencieusement (aucun système à cet endroit, aucun combat).
#
# PIÈGE À CONNAÎTRE (ronde de correction 2, SHRL-46) : dans un même tour, les
# tables d'ordres sont traitées dans l'ordre de leurs index de
# Const.NOMS_TABLES_ORDRES (ReceptionOrdres.deroulementOrdres boucle sur
# index croissant), jamais dans l'ordre où le scénario les écrit. Un ordre
# ne peut donc jamais consommer, le même tour, ce que produit un ordre placé
# plus loin dans ce tableau. Deux exemples vécus :
#   - creer_strategie (index 46) est traité APRÈS deplacer_flotte (index 33) :
#     une stratégie créée au tour N n'est utilisable par un deplacer_flotte
#     qui la référence par son nom qu'à partir du tour N+1
#     (Commandant.deplacerFlotte retombe silencieusement, sans erreur, sur
#     la stratégie par défaut si le nom est encore inconnu).
#   - programmer_construction ne rend pas le vaisseau construit disponible
#     ce même tour : la production a sa propre durée (le nombre de tours du
#     plan), et un ordre qui voudrait l'utiliser (deplacer_flotte,
#     construire_flotte...) doit attendre le tour où la construction est
#     effectivement sortie du chantier.
# Un scénario qui enchaîne deux actions dépendantes doit donc les étaler sur
# des tours distincts, jamais les écrire dans le même turn-N.sql en comptant
# sur l'ordre d'écriture.
#
# PIÈGE À CONNAÎTRE (le plus coûteux du chantier, SHRL-46) : setup.sql ne peut
# accorder AUCUN état d'univers. Les tables SQL ne portent que les inscriptions
# et les ordres ; l'état du jeu (technologies connues, possessions, flottes,
# planètes) vit dans data/, écrit par le moteur, et aucune table d'ordres ne
# permet d'y injecter quoi que ce soit avant le premier tour. Conséquence
# directe et non contournable : tout ordre exigeant une technologie hors de
# Const.RACE_TECHNOLOGIES[race] et hors du domaine public initial (seuls mineI
# et chantierI, DeroulementDuTour.java:23-25) coûte un TOUR DE RECHERCHE
# PRÉALABLE, la technologie n'étant connue qu'à la fin de la résolution du tour
# où elle est cherchée. C'est la raison pour laquelle quatre des cinq scénarios
# consacrent leur tour 1 à affecter_recherche. Toute technologie de niveau 0
# sans parent est cherchable dès le tour 1 (Commandant.peutChercherTechnologie
# → Technologie.listeDesTechnologiesAtteignables, Technologie.java:245-267) ;
# une technologie à parent en coûte autant de tours qu'elle a d'ancêtres
# inconnus. Vécu : creer_strategie exige stratcoI, creer_alliance exige diploI,
# ni l'une ni l'autre connue d'aucune race au départ.
#
# PIÈGE À CONNAÎTRE (généralisation des trois précédents, SHRL-46) : une
# colonne d'ordre ne porte pas toujours ce que son nom suggère, et le moteur
# accepte un mauvais argument SANS émettre d'erreur. La garde <m type="ERR">
# de run-scenario.sh ne rattrape donc pas cette classe de faute : seule une
# assertion sur l'effet de jeu la voit. Quatre cas rencontrés :
#   - deplacer_flotte.POSX alimente Y et POSY alimente X (cf. piège ci-dessus) ;
#   - exclure_alliance.VOTE porte le NUMÉRO du commandant visé, pas un booléen
#     (ReceptionOrdres.java:489 vers voterExclusionCommandant(int, int)).
#     Un premier essai a exclu le mauvais commandant sans la moindre erreur,
#     et c'est l'assertion alliance.0.membres qui l'a rattrapé, pas la garde ;
#   - aa_vaisseaux.VAISSEAU est un indice de 1 à 5 dans une table de quotas
#     nommés, pas un numéro de plan de vaisseau, et la table REMPLACE la flotte
#     au lieu de s'y ajouter : dès que la map est non vide, tous les quotas sont
#     remis à zéro (Flotte.java:280) avant d'appliquer les indices présents.
#     Conséquence plus dure qu'un simple « ignoré » : une ligne unique hors de
#     1..5 donne une flotte VIDE, sans erreur. Et la PREMIÈRE ligne de la table
#     n'est jamais lue, r2.first() plaçant déjà le curseur sur elle avant que
#     while (r2.next()) ne la saute (ProductionOrdres.java:493-495) : le premier
#     commandant inscrit garde la flotte par défaut. Bug moteur, suivi en
#     SHRL-54 (Flotte.choixFlotteDeDepart, Flotte.java:257-306) ;
#   - le dump écrit marchandise.<code> = <PRIX>/<QUANTITE> (cf. piège plus bas).
# Règle qui en découle : tout scénario doit porter au moins une assertion sur
# un EFFET DE JEU observable, jamais seulement sur la présence des acteurs.
#
# PIÈGE À CONNAÎTRE (ronde de correction 1 de la tâche 8, SHRL-46) : l'oracle
# de déterminisme (check-determinisme.sh) ne peut attester QUE de ce que ses
# artefacts comparés montrent. Avant cette ronde, il ne comparait que les
# dump-tour-*.txt ; il compare désormais aussi les rapports XML
# (data/tour<n>/rapports/**/rapport.xml). Mais même élargi, il reste
# structurellement aveugle à deux choses :
#   - ce que DumpEtat n'écrit jamais : aucun message, aucun événement, rien
#     de ce qui vit dans Commentaire (Commentaire.java:17-42, une ArrayList
#     en ordre d'insertion). Un non-déterminisme qui ne porte QUE sur l'ordre
#     des messages d'un commandant ne se voit que dans son rapport XML,
#     jamais dans son dump.
#   - ce que DumpEtat réordonne avant d'écrire : DumpEtat.ecrireMarche
#     re-trie déjà les offres du marché par identifiant croissant
#     (DumpEtat.java:258-263) avant de les écrire, donc même la section
#     marché du dump est insensible à l'ordre d'itération de la structure
#     qui les a produites.
# Concrètement : un scénario peut exercer un vrai défaut d'ordre
# d'itération (ex. une Map dont la clé n'a ni equals() ni hashCode(), donc
# hachée par identité mémoire) sans que check-determinisme.sh ne rende jamais
# rouge, si l'unique effet observable de cet ordre tombe dans l'un des deux
# angles morts ci-dessus. Ne pas conclure "aucun défaut" d'un run vert sans
# avoir vérifié CE QUE l'oracle compare réellement pour le scénario en
# question. Vécu sur 03-marche (SHRL-46, task-8) : reglerEncheresMarche()
# itérait une Map<OffreMarche, List<Enchere>> hachée par identité, 8
# exécutions consécutives de check-determinisme.sh restaient vertes tant que
# seuls les dumps étaient comparés, l'effet réel (ordre des messages d'achat
# dans le rapport de l'acheteur) n'étant devenu visible qu'après l'ajout de
# la comparaison XML ci-dessus.
#
# PIÈGE À CONNAÎTRE (format du dump, ronde de correction 1 de la tâche 8,
# SHRL-46) : DumpEtat.ecrirePossession écrit
# ".marchandise.<code> = <PRIX>/<QUANTITE>" (DumpEtat.java:120-122), le prix
# d'abord, la quantité ensuite — l'inverse d'une lecture naïve. Une ligne
# "marchandise.7 = 49/1" signifie prix 49, quantité 1, pas quantité 49.
# Piège vécu sur 03-marche : un ordre vendre_galactique visant à vendre 40
# ou 50 unités d'une marchandise lue "= 49/1" échoue systématiquement
# (ER_COMMANDANT_VENTE_GALACTIQUE_0002), silencieusement côté dump, visible
# seulement dans le rapport XML du vendeur.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MYSQL_CLI="${MYSQL_CLI:-docker compose exec -T db mysql}"
DB_HOST="${DB_HOST:-127.0.0.1:3311}"

# Jar employé par tout le harnais. Surchargeable pour viser un binaire de
# travail construit par SHERIL_JAR_SORTIE=test/work/sheril.jar, sans salir le
# ./sheril.jar suivi par git.
#
# Le chemin est ramené en absolu : moteur() se place dans le répertoire de
# travail du scénario avant d'appeler java, donc un SHERIL_JAR relatif (la
# forme naturelle, test/work/sheril.jar) n'y résoudrait plus. Vécu en posant le
# témoin de cette garde : ClassNotFoundException sur Start, cause invisible
# parce qu'elle partait dans init.log.
JAR="${SHERIL_JAR:-$REPO/sheril.jar}"
# Si le parent n'existe pas, le chemin est laissé TEL QUEL plutôt que réduit à
# "/$(basename)" : le message d'échec doit nommer ce que l'utilisateur a fourni,
# pas un chemin fantôme fabriqué par la normalisation elle-même.
case "$JAR" in
  /*) ;;
  *)
    if _d="$(cd "$(dirname "$JAR")" 2>/dev/null && pwd)"; then
      JAR="$_d/$(basename "$JAR")"
    fi
    unset _d ;;
esac

# Refuse de démarrer si le jar ne porte pas le bytecode de dumpState.
#
# Ce contrôle existe en intégration continue depuis la tâche 10, sur le jar que
# le job build publie. Il n'existait PAS en local, et c'est pourtant là que
# l'incident s'est produit deux fois : le ./sheril.jar suivi par git est en
# retard sur les sources, et Start.main N'ÉCHOUE PAS sur une action inconnue,
# il affiche son aide et rend 0. Un `Start dumpState fichier` sur un jar périmé
# ne produit donc aucun fichier, sans le dire, et le harnais échoue plus loin
# en désignant la mauvaise cause, sur une résolution de marqueur ou une
# comparaison de golden. Les deux faux signaux vécus (« des galaxies
# différentes entre deux répétitions ») venaient de là.
verifier_jar() {
  if [ ! -f "$JAR" ]; then
    echo "ECHEC: $JAR est absent. Construire le jar : bash scripts/create-jar.sh" >&2
    return 1
  fi
  # Le contenu passe par une variable plutôt que par « jar tf | grep -q ». Sous
  # set -o pipefail, grep -q s'arrête à la première correspondance, ce qui peut
  # faire sortir jar sur SIGPIPE (141) : le pipeline échouerait alors qu'il
  # vient précisément de TROUVER la classe, et la garde accuserait un jar sain.
  # Un contrôle ne doit pas tirer son verdict d'un statut qui dépend de l'ordre
  # d'entrées dans une archive.
  # L'échec de la commande jar est distingué d'un jar périmé, et sa cause est
  # restituée. Avaler le code de retour par « 2>/dev/null || true » rendait une
  # chaîne vide, donc un diagnostic « périmé, reconstruisez-le » sur un jar
  # parfaitement à jour, avec un remède sans effet. Un simple « command -v jar »
  # ne suffit pas : macOS fournit un /usr/bin/jar factice qui existe, répond
  # « Unable to locate a Java Runtime » et sort en erreur. Seul le code de
  # retour de l'appel réel discrimine.
  local contenu statut=0
  contenu="$(jar tf "$JAR" 2>&1)" || statut=$?
  if [ "$statut" -ne 0 ]; then
    echo "ECHEC: impossible de lire $JAR avec la commande jar (code $statut). Cause ci-dessous." >&2
    printf '%s\n' "$contenu" >&2
    echo "       Ce n'est PAS un jar périmé : ajouter le JDK au PATH, par exemple" >&2
    echo "       sous macOS avec Homebrew, PATH=\"/opt/homebrew/opt/openjdk/bin:\$PATH\"" >&2
    return 1
  fi
  # La comparaison est ancrée par des sauts de ligne, pour rester une égalité
  # d'entrée et non une inclusion de sous-chaîne : « Start.class » ne doit pas
  # être satisfait par « zIgzAg/.../AutreStart.class ».
  case $'\n'"$contenu"$'\n' in
    *$'\n'"zIgzAg/jeu/oceane/DumpEtat.class"$'\n'*) ;;
    *)
    echo "ECHEC: $JAR ne contient pas DumpEtat.class, il est périmé par rapport aux sources." >&2
    echo "       Le harnais en a besoin pour l'action dumpState, et Start rend 0 sur une" >&2
    echo "       action inconnue, donc l'échec se manifesterait plus loin sous une fausse cause." >&2
    echo "       Reconstruire : bash scripts/create-jar.sh" >&2
    echo "       Ou, pour ne pas salir le jar suivi par git :" >&2
    echo "       SHERIL_JAR_SORTIE=test/work/sheril.jar bash scripts/create-jar.sh" >&2
    echo "       puis SHERIL_JAR=test/work/sheril.jar avant de relancer le harnais." >&2
      return 1 ;;
  esac
}

# Recharge un schéma vierge dans la base sheril.
reinitialiser_base() {
  ( cd "$REPO" && $MYSQL_CLI -uroot -ppassword -e "DROP DATABASE IF EXISTS sheril; CREATE DATABASE sheril;" )
  ( cd "$REPO" && $MYSQL_CLI -uroot -ppassword sheril < "$REPO/divers/base_sheril.sql" )
}

# Injecte un fichier SQL dans la base sheril.
injecter_sql() {
  ( cd "$REPO" && $MYSQL_CLI -uroot -ppassword sheril < "$1" )
}

# Prépare un répertoire d'exécution isolé et y écrit config.properties.
# $1 répertoire, $2 graine, $3 date figée
preparer_workdir() {
  local work="$1" seed="$2" date_figee="$3"
  rm -rf "$work"
  mkdir -p "$work/data/commun" "$work/php/rapports" "$work/php/stats"
  cp -R "$REPO/data/fichiers" "$work/data/fichiers"
  echo "0" > "$work/data/commun/tour.txt"
  cat > "$work/config.properties" <<EOF
PATH_DATA = ./data/
PATH_EXPORT_ZIPPED_RAPPORT = ./rapports/
PATH_TOUR = ./data/commun/tour.txt
PATH_STATS = ./data/stats/
RACINE_SITE = http://localhost:666/
IRC_MAIN_CHANNEL = #sheril
SSH_PORT = 22
SSH_BASE_PATH = user@host:/vhosts/
DATABASE_HOST = $DB_HOST
DATABASE_LOGIN = user
DATABASE_PASSWORD = password
DATABASE_NAME = sheril
NOTIFY_BOT = false
FAKE_TURN = false
IS_LOCAL = true
PATH_PHP = ./php/
RANDOM_SEED = $seed
DATE_FIGEE = $date_figee
EOF
}

# Lance une action du moteur depuis le répertoire d'exécution.
moteur() {
  local work="$1"; shift
  ( cd "$work" && java -cp "$JAR" Start "$@" )
}

# Même chose, mais en journalisant, et en RESTITUANT le journal si l'action
# échoue. Sans cela, un moteur qui ne démarre pas fait avorter l'appelant sous
# set -e en n'ayant rien imprimé d'autre que la ligne « -- init » qui précède :
# la cause réelle reste enfermée dans un fichier que personne ne va lire, et
# l'échec paraît venir de l'étape suivante. Vécu en posant le témoin de la
# garde de jar, sur un ClassNotFoundException.
# $1 répertoire, $2 fichier de journal, puis l'action et ses arguments.
moteur_journalise() {
  local work="$1" journal="$2"; shift 2
  if ! moteur "$work" "$@" > "$journal" 2>&1; then
    echo "ECHEC: le moteur a échoué sur l'action « $* », journal ci-dessous ($journal)" >&2
    cat "$journal" >&2
    return 1
  fi
}

# Lit une clé de scenario.properties. Échoue si la clé est absente OU si elle
# est présente avec une valeur vide.
#
# La distinction compte, et la garde ne couvre pas les deux cas pour la même
# raison. Clé ABSENTE : le `grep` sans correspondance faisait déjà échouer la
# fonction sous `set -o pipefail`, donc l'appelant avortait bruyamment. Clé
# PRÉSENTE MAIS VIDE (`TOURS =`) : la fonction rendait une chaîne vide avec un
# code 0, et l'appelant continuait avec une valeur qu'il n'a jamais vérifiée.
# C'est ce second cas qui a produit un vert : `check-determinisme.sh` bâtit sa
# boucle de comparaison sur `seq 1 "$TOURS"`, `seq 1 ""` échoue sans faire
# échouer la liste d'un `for`, donc zéro itération, zéro dump comparé, et le
# script conclut « reproductible » avec un code 0. Le même `TOURS` vide donne
# `tour$((tours+1))` = `tour1` dans deux jobs du workflow, et un `RANDOM_SEED`
# vide ferait tourner le moteur NON SEMÉ avec des goldens qui divergent de
# façon erratique.
#
# `grep -m1` plutôt que `| head -1` : `head` ferme le tuyau dès la première
# ligne lue, ce qui peut faire sortir `grep` sur SIGPIPE (141) et faire échouer
# le pipeline sous `pipefail` pour une raison qui n'a rien à voir avec la clé.
propriete() {
  local v
  if ! v="$(grep -m1 -E "^$2[[:space:]]*=" "$1" | cut -d= -f2- | xargs)"; then
    echo "ECHEC: clé $2 absente de $1" >&2
    return 1
  fi
  if [ -z "$v" ]; then
    echo "ECHEC: clé $2 présente mais vide dans $1, aucune valeur par défaut n'est supposée" >&2
    return 1
  fi
  printf '%s\n' "$v"
}

# Lit une clé FACULTATIVE. Rend une chaîne vide, sans message, quand la clé est
# absente ou vide.
#
# Réservé aux clés dont l'absence est un cas légitime et dont le défaut est
# explicite chez l'appelant (aujourd'hui la seule est ERREURS_TOLEREES, dont
# l'absence vaut « false »). Ne jamais l'employer pour une clé dont dépend le
# déroulé du scénario : c'est précisément le silence de `propriete` sur une
# valeur vide qui a produit un vert sans rien exercer.
propriete_optionnelle() {
  propriete "$1" "$2" 2>/dev/null || true
}

# Lit TOURS et impose son contrat : un entier strictement positif.
#
# La garde de non-vacuité de `propriete` ne suffit pas ici. Une valeur non vide
# mais non numérique (`TOURS = 2 tours`, `TOURS = huit`) la traverse, et rouvre
# exactement le chemin décrit ci-dessus : `seq 1 "2 tours"` échoue, la boucle
# n'itère pas, et le script rend vert sans avoir rien comparé. Le contrat sur la
# valeur appartient donc à l'appelant qui sait ce qu'il attend, pas au lecteur
# de propriétés générique.
tours_du_scenario() {
  local v
  v="$(propriete "$1" TOURS)" || return 1
  case "$v" in
    *[!0-9]*)
      echo "ECHEC: TOURS invalide dans $1 : [$v], un entier strictement positif est attendu" >&2
      return 1 ;;
  esac
  # Les zéros de tête sont retirés : les appelants font $((TOURS+1)), et bash
  # interprète un entier préfixé de 0 comme de l'octal. TOURS = 08 lèverait
  # « value too great for base » au milieu du contrôle des rapports, très loin
  # de sa cause.
  v="$((10#$v))"
  if [ "$v" -lt 1 ]; then
    echo "ECHEC: TOURS = $v dans $1, un scénario doit jouer au moins un tour" >&2
    return 1
  fi
  printf '%s\n' "$v"
}
