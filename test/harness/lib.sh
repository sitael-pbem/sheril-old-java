#!/usr/bin/env bash
# Fonctions communes aux scripts du harnais.
# Aucune de ces fonctions ne connaît le contenu d'un scénario.

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
