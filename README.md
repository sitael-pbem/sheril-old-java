
# Moteur de jeu basé sur celui d'océane https://github.com/ydomenjoud/oceane 

## tl;dr
```shell
git clone git@github.com:ydomenjoud/sheril-old-java.git sheril
cd sheril
docker compose up -d
docker compose exec engine bash ./scripts/init.sh
```
Aller sur http://localhost:666 pour créer votre premier commandant
Puis passer le tour avec :
```shell
docker compose exec engine java -cp sheril.jar Start newRound
```

## Pour lancer le jeu sous DOCKER

### démarrage de la base de données, la console et le moteur
```shell
docker compose up -d
```

### initialisation environnement + Univers
```shell
docker compose exec engine bash ./scripts/init.sh
```

### Faire tourner un tour
```shell
docker compose exec engine java -cp sheril.jar Start newRound
```

### lister les commandants et leur mot de passe
```shell
docker compose exec db mysql -u user -p"password" sheril -e "SELECT NOM,NUMERO,LOGIN,MOT_DE_PASSE FROM aa_registre;"
```

### recréer le jar suite à une modification du code source
```shell
docker compose exec engine bash ./scripts/create-jar.sh
```

### recréer le jar suite à une modification du code source
```shell
docker compose exec engine bash ./scripts/clean.sh
```

### relire visuellement les rapports produits par un tour

Le moteur écrit déjà les rapports en HTML statique, un répertoire par commandant,
sous `data/tour<N>/rapports/<numCommandant>tour<N>/`. Le script suivant les rend en
images et en PDF, et bâtit une galerie parcourable pour les relire d'un coup d'œil :

```shell
python3 scripts/capture-rapports.py data/tour3/rapports --archiver
open capture-rapports/index.html
```

Il ne dépend que de `python3` et d'un Chrome ou Chromium local. `--archiver` recopie
au passage le HTML source, qui vit dans `data/` (ignoré par git, réécrit à chaque tour).
`python3 scripts/capture-rapports.py --help` liste les options : filtrage par
commandant, par page, taille du viewport, parallélisme.

### comparer deux séries de rapports

Le même script compare deux arbres page à page et rend un verdict. `--diff-seul`
ne lit que le HTML, donc ne lance jamais Chrome :

```shell
python3 scripts/capture-rapports.py data/tour2/rapports \
    --diff /chemin/vers/reference/rapports --diff-seul
open capture-rapports/diff.html
```

La référence est soit un autre répertoire `rapports/` du moteur, soit une sortie
de capture produite avec `--archiver`. Le rapport `diff.html` donne, par
commandant et par page, un statut (identique, identique hors date, modifiée,
ajoutée, supprimée) et le diff des pages qui ont changé. Les codes de retour
suivent la convention de `diff(1)` : `0` aucune différence, `1` des différences,
`2` au moins une page n'a pas pu être rendue.

La date du rapport (`Utile.getDateRapport()`, `Utile.java:218`) est neutralisée
avant comparaison, sinon deux tours identiques différeraient sur chaque page qui
l'affiche. `--diff-brut` la conserve, `--ignorer <regex>` neutralise d'autres
motifs. Le HTML est redécoupé sur ses balises de structure avant comparaison :
le moteur l'écrit d'un seul jet, et `detailF.htm` tient sur 3 lignes dont une de
25 Ko, sur laquelle un diff ligne à ligne n'apprend rien.

**Le moteur n'est pas déterministe**, ce qui borne l'usage en non-régression.
Mesure du 2026-08-19 : un même tour rejoué deux fois depuis un état restauré à
l'identique (base MySQL rechargée depuis un dump, `data/` restauré depuis une
archive) laisse 15 pages sur 21 rigoureusement identiques, mais `principal.htm`
et `detailF.htm` diffèrent pour les trois commandants. Les valeurs qui bougent
sont tirées au hasard à chaque exécution : noms de vaisseaux, dommages et
composants détruits, puissance, réputation. Une comparaison d'octets ne fait
donc foi que sur le sous-ensemble stable des pages.

