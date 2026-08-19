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
#     (DumpEtat.java:250-255) avant de les écrire, donc même la section
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
# ".marchandise.<code> = <PRIX>/<QUANTITE>" (DumpEtat.java:111-113), le prix
# d'abord, la quantité ensuite — l'inverse d'une lecture naïve. Une ligne
# "marchandise.7 = 49/1" signifie prix 49, quantité 1, pas quantité 49.
# Piège vécu sur 03-marche : un ordre vendre_galactique visant à vendre 40
# ou 50 unités d'une marchandise lue "= 49/1" échoue systématiquement
# (ER_COMMANDANT_VENTE_GALACTIQUE_0002), silencieusement côté dump, visible
# seulement dans le rapport XML du vendeur.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MYSQL_CLI="${MYSQL_CLI:-docker compose exec -T db mysql}"
DB_HOST="${DB_HOST:-127.0.0.1:3311}"

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
  ( cd "$work" && java -cp "$REPO/sheril.jar" Start "$@" )
}

# Lit une clé de scenario.properties.
propriete() {
  grep -E "^$2[[:space:]]*=" "$1" | head -1 | cut -d= -f2- | xargs
}
