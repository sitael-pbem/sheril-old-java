
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

## Harnais de non-régression du moteur

Cinq scénarios de jeu joués de bout en bout, dont l'état final est sérialisé en
texte trié et comparé à une référence versionnée. Le but est de rendre visible en
revue, ligne à ligne, ce qu'une modification du moteur change réellement dans une
partie. Tout tourne aussi en intégration continue, `.github/workflows/harness.yml`.

Prérequis : la base de données démarrée (`docker compose up -d db`) et un
`sheril.jar` à jour contenant l'action `dumpState`.

### jouer un scénario

```shell
bash test/harness/run-scenario.sh 01-combat
```

Le script recharge un schéma vierge, joue les tours, compare chaque tour à son
golden, vérifie les assertions et refuse tout `<m type="ERR">` dans un rapport.
Ses artefacts (dumps, diffs, journaux de tour) vivent sous
`test/work/<scenario>/`, ignoré par git.

### ajouter un scénario

Un scénario est un dossier sous `test/scenarios/`, jamais une ligne de script :
`scenario.properties` (graine, date figée, nombre de tours), `setup.sql`
(inscriptions), un `turn-N.sql` par tour qui en porte, `assertions.txt` sur le
dernier tour, un `assertions-tour-N.txt` facultatif par tour intermédiaire, et
`golden/`. Les ordres peuvent référencer des valeurs de la partie en cours par
des marqueurs résolus depuis le dump du tour précédent, `@NUM(Alpha)@`,
`@CAPX(Alpha)@`, `@FLOTTE(Alpha,0)@`, `@OFFRE(Alpha,0)@`.

**Lire l'en-tête de `test/harness/lib.sh` avant d'écrire le premier ordre.** Il
porte six pièges du moteur qui ont chacun coûté une correction à ce chantier,
dont deux qui font qu'un ordre mal écrit est accepté sans la moindre erreur : une
colonne de position dont X et Y sont transposés, et une colonne de vote qui porte
un numéro de commandant là où le nom suggère un booléen.

Chaque scénario doit porter au moins une assertion sur un **effet de jeu**
observable, jamais seulement sur la présence des joueurs. C'est la seule chose
qui survit à une régénération de golden, et c'est ce qui a rattrapé les fautes
que la garde d'erreur moteur ne voyait pas.

### régénérer les goldens après un changement voulu

```shell
bash test/harness/update-golden.sh 01-combat
git diff test/scenarios/01-combat/golden/
```

Les assertions restent vérifiées pendant la régénération, un scénario cassé ne
peut donc pas voir ses références bénies en silence. Le diff est à relire avant
de committer : un tour fait bouger environ 320 lignes de dump même sans action du
joueur, croissance de population et de minerai comprises.

### contrôler que le moteur rejoue à l'identique

```shell
bash test/harness/check-determinisme.sh 01-combat
```

Joue deux fois le même scénario dans deux répertoires distincts et compare dumps
et rapports XML, sans jamais toucher au golden. Les autres contrôles unitaires du
harnais sont `check-dumpstate.sh`, `check-init-determinisme.sh`,
`check-date-figee.sh` et `check-composants-determinisme.sh`.

### portée

Les cinq scénarios touchent 15 des 62 tables d'ordres que déclare le moteur, et
la quinzième est `ecrire_article`, employée 21 fois comme simple garde contre
l'élimination pour inactivité. Quatorze ordres sont donc réellement exercés. Un
scénario vert ne dit rien des 47 autres.

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

**Le moteur n'est pas déterministe par défaut**, ce qui borne l'usage en
non-régression. Mesure du 2026-08-19 : un même tour rejoué deux fois depuis un
état restauré à l'identique (base MySQL rechargée depuis un dump, `data/`
restauré depuis une archive) laisse 15 pages sur 21 rigoureusement identiques,
mais `principal.htm` et `detailF.htm` diffèrent pour les trois commandants. Les
valeurs qui bougent sont tirées au hasard à chaque exécution : noms de
vaisseaux, dommages et composants détruits, puissance, réputation. Une
comparaison d'octets ne fait donc foi que sur le sous-ensemble stable des pages.

Il peut en revanche être **rendu reproductible à la demande**, par la propriété
`RANDOM_SEED` de `config.properties`, sur laquelle repose le harnais décrit
ci-dessous. Cette propriété n'est pas déclarée dans `config.properties.sample` :
en son absence le moteur tire au hasard comme il l'a toujours fait.

