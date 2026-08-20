#!/bin/bash

# a lancer à la racine
#
# Chemin de sortie surchargeable par SHERIL_JAR_SORTIE, defaut ./sheril.jar
# inchange. Motif : ./sheril.jar est suivi par git, et le harnais de
# non-regression impose de recompiler a chaque modification des sources. Sans
# cette porte, tout aller-retour de developpement salit un binaire versionne,
# qu'on finit par committer par megarde ou par restaurer a la main. Un build de
# travail vise donc SHERIL_JAR_SORTIE=test/work/sheril.jar, sous un repertoire
# deja ignore. L'integration continue ne depend pas du jar versionne, le job
# build le recompile et le publie en artefact.
JAR_SORTIE="${SHERIL_JAR_SORTIE:-./sheril.jar}"
mkdir -p "$(dirname "$JAR_SORTIE")"

export LIBS_PATH=$(find ./libs -name "*.jar" | tr '\n' ':')
mkdir -p ./classes

echo "Compilation en cours..."

set -o pipefail
find ./sources -name "*.java" -print | xargs javac -nowarn -Xlint:none -cp "${LIBS_PATH}" -d ./classes 2>&1


# On crée un dossier temporaire pour extraire les dépendances
mkdir -p ./tmp_libs
cd ./tmp_libs
for jar_file in ../libs/*.jar; do
    jar -xf "$jar_file" # On extrait le contenu de chaque lib
done
# On nettoie les manifestes des dépendances pour ne pas écraser le nôtre
rm -rf META-INF
cd ..

# On fusionne tes classes ET les classes extraites dans le JAR final
jar -cf "$JAR_SORTIE" -C ./classes . -C ./tmp_libs . > /dev/null

# Nettoyage du dossier temporaire
rm -rf ./tmp_libs

echo "✅ $JAR_SORTIE créé avec succès"