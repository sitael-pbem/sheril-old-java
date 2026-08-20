# Harnais de non-régression du moteur

Design validé le 2026-08-18. Projet Jira : `SHRL`.

## 1. Le problème

Le moteur se modifie sans filet. La seule vérification automatique aujourd'hui
est `.github/workflows/compile.yml`, qui compile les sources à chaque PR. Un
changement qui compile mais casse la résolution d'un combat, l'attribution d'une
enchère ou la croissance d'une population passe sans obstacle jusqu'au tour joué
en production.

Ce document décrit un harnais qui rejoue des parties connues et compare leur
résultat à une référence versionnée.

## 2. Objectifs

1. Détecter tout changement de comportement du moteur sur cinq scénarios
   couvrant combat, colonisation, marché galactique, recherche et alliances.
2. Rendre ce changement **lisible en revue** : le diff des références part dans
   la PR et montre l'effet du code sur la partie témoin.
3. Rendre l'échec **reproductible en local** avec une seule commande.

### Hors périmètre

- La console PHP. Le harnais utilise la base de données pour injecter des
  ordres, il ne teste pas les formulaires qui les produisent normalement.
- Le rendu HTML des rapports. Il est couvert par un chantier parallèle, décrit
  en section 8.
- Toute réécriture du moteur qui ne sert pas directement le déterminisme. Les
  corrections de la section 3.3 sont retenues parce qu'elles conditionnent la
  faisabilité, pas au titre du nettoyage.

## 3. Lot 1 : rendre le tour reproductible

Aucun golden n'a de sens tant que deux exécutions du même tour, sur le même état
d'entrée et les mêmes ordres, peuvent différer. C'est aujourd'hui le cas.

### 3.1 Semer le générateur aléatoire

Tout le hasard du déroulement passe par un `Random` unique : déclaré en
`Univers.java:40`, instancié en `Univers.java:1100`, consommé par
`Univers.getInt(int)` (`Univers.java:355`), `Univers.getTabInt(...)`
(`Univers.java:359`) et `Univers.getBoolean()` (`Univers.java:366`).

Ajouter une propriété `RANDOM_SEED` lue par `Const`, et en `Univers.java:1100` :

```java
HASARD = (Const.RANDOM_SEED == null) ? new Random() : new Random(Const.RANDOM_SEED);
```

Propriété absente de `config.properties`, comportement inchangé. La production
n'est pas concernée.

Il subsiste un `new Random()` local en `AugmentationTaille.java:17`, qui ne sert
qu'à l'ajout de galaxie. Il doit passer par `Univers.getInt` pour que
`Start init` soit lui aussi reproductible, puisque le harnais génère l'univers
de chaque scénario.

### 3.2 Figer la date

`Utile.getDateRapport()` (`Utile.java:218`) construit une date `JJ/MM/AAAA`
depuis un `GregorianCalendar` courant. Elle a un unique appelant,
`Rapport.java:1296`, qui l'insère dans le rapport HTML.

Ajouter une propriété `DATE_FIGEE` et, quand elle est présente, la retourner
telle quelle. Comme pour la graine, absente signifie comportement inchangé.

Ce point ne sert pas le golden de ce document, qui ne compare pas le HTML. Il
est dans le lot 1 parce qu'il est gratuit une fois qu'on touche à ce groupe de
réglages, et parce qu'il rend comparables les captures du chantier de la
section 8.

### 3.3 Neutraliser les maps à clé identitaire

`ReceptionOrdres.java:50` stocke les enchères dans une
`Map<OffreMarche, List<Enchere>>`. `OffreMarche` (`OffreMarche.java:5`)
n'override ni `equals` ni `hashCode`, donc la clé est hachée par identité
mémoire et le parcours de `entrySet()` en `ReceptionOrdres.java:260` change d'une
exécution de JVM à l'autre. Chaque offre réglée débitant les centaures de
l'acheteur, un commandant qui enchérit sur deux offres sans avoir les moyens des
deux remporte l'une ou l'autre selon l'ordre.

**Ce n'est pas seulement un obstacle au test.** En partie réelle l'attribution
est arbitraire et non reproductible, ce qui est indéfendable devant un joueur qui
conteste. La correction est due indépendamment du harnais.

Correction : trier les offres sur un critère métier stable avant le règlement.
L'identifiant d'offre (`ID_OFFRE`, colonne de `z_galactique`) convient.

Le même motif touche l'affichage : `HashMap<ComposantDeVaisseau, Integer>` en
`PlanDeVaisseau.java:772`, `RapportXML.java:556` et `DataXML.java:253`, avec un
`ComposantDeVaisseau` (`ComposantDeVaisseau.java:7`) qui n'override pas davantage
`hashCode`. L'ordre des composants d'un plan varie donc d'un run à l'autre.
Remplacer par une `LinkedHashMap` suffit là où seul l'ordre d'insertion importe.

### 3.4 Le contrôle témoin

Les trois points ci-dessus viennent d'une recherche par heuristique, pas d'une
preuve. Le harnais porte donc un contrôle qui ne dépend d'aucune référence :
rejouer deux fois le même scénario dans la même exécution de CI et exiger deux
dumps identiques.

C'est ce contrôle qui atteste du déterminisme, pas la lecture du code. Tant
qu'il est rouge, les cinq goldens ne veulent rien dire.

## 4. Lot 2 : le dump d'état

Malgré leur extension, `data/tour<N>/donnees/*.txt` sont des objets Java
sérialisés (`Univers.sauvegarderMap`, `Univers.java:1436`). Binaires, ils sont
inutilisables comme référence : illisibles en revue, interdits en commit, et
invalidés par le moindre changement de champ d'une classe.

Nouvelle commande `java -cp sheril.jar Start dumpState <fichier>`, produisant un
texte canonique de l'état objectif :

- par commandant, trié par numéro : centaures, budget par domaine, technologies
  connues, recherches en cours, possessions par position, flottes avec position,
  direction et composition ;
- par système, trié par position : planètes, propriétaire, population, stocks ;
- les alliances et leurs membres ;
- les offres du marché en cours.

Une donnée par ligne, format `clé = valeur` à plat, tri par identifiant numérique
à tous les niveaux. Le format est choisi pour que `diff` désigne précisément ce
qui a bougé, pas pour être compact.

La commande sert aussi au diagnostic hors CI, ce qui justifie qu'elle vive dans
`Start` et non dans le harnais.

## 5. Lot 3 : le harnais

```
test/
  harness/
    run-scenario.sh        # init, tours, dump, comparaison, assertions
    update-golden.sh       # régénère les références
  scenarios/
    01-combat/
      scenario.properties  # graine, date figée, nombre de tours
      setup.sql            # INSERT aa_inscription + aa_vaisseaux
      turn-1.sql …         # ordres injectés avant chaque tour
      assertions.txt       # attentes minimales sur le dump final
      golden/
        dump-tour-<N>.txt
    02-colonisation/  03-marche/  04-recherche/  05-alliances/
```

`run-scenario.sh <scenario>` déroule toujours la même séquence :

1. écrire un `config.properties` de test : `RANDOM_SEED` et `DATE_FIGEE` du
   scénario, `NOTIFY_BOT = false` pour ne pas notifier Discord,
   `IS_LOCAL = true` pour que `Start.upload` (`Start.java:215`) copie en local au
   lieu de tenter un `scp` ;
2. `Start init` ;
3. injecter `setup.sql` ;
4. `Start newRound`, qui crée les commandants via `ProductionOrdres.produireRegistre`
   (`ProductionOrdres.java:407`, création en `:503`) ;
5. pour chaque tour : substituer les marqueurs de `turn-N.sql`, l'injecter,
   `Start newRound` ;
6. `Start dumpState`, comparer au golden, évaluer `assertions.txt`, contrôler la
   structure des `rapport.xml`.

Trois propriétés à préserver :

- **Le harnais ignore le contenu des scénarios.** Ajouter un scénario est un
  dossier, jamais une ligne de script.
- **Le même script tourne en local et en CI.** Un golden rouge doit se
  reproduire sur la machine du développeur avec une seule commande, sinon
  personne ne s'en servira.
- **`update-golden.sh` est la seule façon de régénérer une référence**, et son
  diff part en revue.

### 5.1 Les marqueurs

Un ordre référence `NUMERO`, `NUMFLOTTE`, une position de capitale, toutes
attribuées par le moteur et inconnues à l'écriture du scénario. Les écrire en
dur fonctionnerait tant que la graine ne bouge pas, mais c'est un piège : le jour
où la numérotation se décale, les ordres pointent dans le vide, le moteur les
ignore en silence, et `update-golden.sh` entérine un golden où plus rien ne se
passe. Le test devient vert et vide.

Les fichiers d'ordres utilisent donc des marqueurs — `@P1.NUM@`,
`@P1.CAPITALE.X@`, `@P1.FLOTTE1@` — que `run-scenario.sh` substitue à partir du
dump du tour précédent. Un marqueur non résolu est une erreur fatale, pas un
avertissement.

### 5.2 Les assertions

La substitution supprime la cause la plus probable de dégénérescence, pas toutes.
Chaque scénario porte un `assertions.txt` d'une dizaine de lignes exprimant ce
qui doit rester vrai : tel commandant possède au moins deux planètes, un rapport
de combat existe au tour 2, la technologie visée est connue.

Le golden détecte le changement, les assertions garantissent qu'il reste quelque
chose à détecter.

## 6. Lot 4 : les cinq scénarios

Structure commune : `setup.sql` peuple `aa_inscription`
(`NOM`, `ADRESSE`, `RACE`, `FLOTTE`) et `aa_vaisseaux`
(`ADRESSE`, `VAISSEAU`, `NOMBRE`), l'`ADRESSE` servant de clé de jointure et
devant passer `InternetAddress.parse` (`ProductionOrdres.java:461`).

| Scénario | Tours | Ordres injectés | Sous surveillance |
|---|---|---|---|
| `01-combat` | 2 | `deplacer_flotte`, `creer_strategie` | `Combat.resolutionCombats`, `StrategieDeCombatSpatial`, l'attribution des dégâts à l'attaquant corrigée en `a3683e4` |
| `02-colonisation` | 3 | `deplacer_flotte`, `utiliser_colonisateur`, `modifier_taxation_planete` | `Possession`, `Population`, `Planete`, la taxation |
| `03-marche` | 3 | `vendre_galactique`, `acheter_galactique` | Le règlement des enchères, `OffreMarche.gererFinDeVieEncheres` |
| `04-recherche` | à calibrer | `affecter_recherche`, `modifier_budget` | `Univers.gestionTechno`, `Technologie.testDevenirTechnologiesPubliques` |
| `05-alliances` | 4 | `creer_alliance`, `adherer_alliance`, `valider_adhesion_alliance`, `nommer_dirigeant`, `exclure_alliance` | `Alliance.gererAlliances1/2`, `Alliance.traiterVotes` |

`03-marche` a un statut particulier : il est construit pour exhiber le défaut de
la section 3.3. Un acheteur enchérit sur deux offres sans avoir les centaures des
deux, et l'ordre de parcours décide laquelle il remporte. **Avant correction, ce
scénario doit être instable entre deux exécutions.** S'il est stable d'emblée,
l'analyse de la section 3.3 est fausse quelque part et il faut le savoir avant de
bâtir dessus.

`04-recherche` est le seul dont la durée n'est pas fixée ici. Le nombre de tours
nécessaires pour qu'une technologie aboutisse puis bascule au domaine public
dépend du budget et des constantes ; il se calibre à l'écriture du scénario.

## 7. Lot 5 : le workflow GitHub

Quatre jobs.

**`build`** — l'actuel `compile.yml`, inchangé. Il rend la main en une trentaine
de secondes et évite d'attendre le harnais pour une faute de frappe. Les autres
jobs en dépendent.

**`scenarios`** — une matrice sur les cinq dossiers, `fail-fast: false`, chaque
job avec son propre service MySQL :

```yaml
services:
  db:
    image: mysql:5
    env:
      MYSQL_DATABASE: sheril
      MYSQL_USER: user
      MYSQL_PASSWORD: password
      MYSQL_ROOT_PASSWORD: password
    options: >-
      --health-cmd="mysqladmin ping -ppassword" --health-interval=5s
      --health-timeout=5s --health-retries=20
```

Chaque job charge `divers/base_sheril.sql`, construit le jar via
`scripts/create-jar.sh`, puis lance `test/harness/run-scenario.sh`. La matrice
plutôt qu'une boucle parce que l'interface nomme alors directement le scénario en
échec.

En cas d'échec, le job téléverse le dump obtenu et le diff en artefact. Sans
cela, un golden rouge oblige à tout rejouer en local pour voir ce qui a bougé, et
l'outil devient une corvée.

**`determinisme`** — joue `01-combat` deux fois dans le même job et compare les
deux dumps entre eux, sans jamais consulter le golden. Il répond à une question
que les autres jobs ne posent pas : le moteur rend-il deux fois le même résultat.

**`rapports`** — contrôle structurel des `rapport.xml` (`RapportXML.java:606`,
écrits sous `Chemin.RAPPORTS`, soit `data/tour<N>/rapports/<num>/`) : un par
commandant, XML bien formé, non vide. Greffé sur `02-colonisation` pour ne pas
payer un tour supplémentaire.

Déclenchement sur `pull_request`, sur `push` vers `main`, et `workflow_dispatch`.
`update-golden.sh` ne tourne jamais en CI.

## 8. Validation visuelle des rapports HTML

Chantier mené en parallèle par une autre session, livré sur la branche
`feat/capture-rapports` de `origin`, commit `0019a2f`, fichier
`scripts/capture-rapports.py`. Vérifié présent sur le remote.

Contrat d'entrée : un seul argument, le chemin `data/tour<N>/rapports` produit
par le dernier `Start newRound`. Sortie : un PNG et un PDF par page plus une
galerie `index.html`. Code retour 0 si tout a rendu, 1 s'il reste des pages en
échec. Aucune dépendance hors `python3` et un Chrome ou Chromium local, détecté
en cascade avec un `--chrome` de secours.

Ce chantier ne recouvre pas le présent document : le HTML de `Rapport.java` est
explicitement hors du périmètre de comparaison, pour deux raisons. Il porte une
date (`Rapport.java:1296`), et sa mise en forme change souvent, ce qui en ferait
un golden bruyant. Une capture se regarde, elle ne se diffe pas.

Attention au chemin, les deux sorties ne cohabitent pas au même endroit : le XML
est sous `rapports/<num>/`, le HTML sous `rapports/<num>tour<N>/`
(`Rapport.java:755`), avec un CSS référencé en relatif (`Rapport.java:61`) copié
par `Chemin.initialiserChemins`.

Intégration prévue : un job `captures`, distinct du job `rapports` de la
section 7 bien que les deux consomment la sortie de `02-colonisation`. Le job
`rapports` contrôle le XML et sa rupture est un échec ; le job `captures` produit
des images et reste terminal et non bloquant. Un échec de capture ne doit pas
faire tomber le golden.

**Réserve, telle que la session auteure la formule** : le script est validé sur
une fixture reconstruite à partir des vrais gabarits, jamais sur une sortie
moteur réelle. Le premier tour produit par ce harnais sera aussi son premier test
grandeur nature. Il a donc été convenu de lui transmettre un chemin réel en local
**avant** de câbler le job en CI.

## 9. Risques et inconnues

**Le coût d'un tour n'est pas mesuré.** `Const.NB_SYSTEME` vaut
`NB_SECTEURS * 17` et est `static final` (`Const.java:95`) ; la galaxie de test
est donc une galaxie complète, avec autant de flottes neutres que de systèmes
(`Const.java:97`). Cinq scénarios de trois à six tours peuvent représenter
quelques minutes comme beaucoup plus. **Première tâche du plan : mesurer un
tour**, avant toute autre écriture. Si c'est trop lent, le levier est de rendre
ces deux constantes configurables en gardant les valeurs de production par
défaut, mais cette décision attend la mesure.

**La présence d'un Chrome sur le runner `ubuntu-latest` n'est pas vérifiée.**
À confirmer au moment d'écrire le job de la section 8. Si l'image n'en embarque
pas, cela se règle par une étape d'installation.

**Le déterminisme n'est pas prouvé, seulement rendu probable.** La section 3.3
liste ce qu'une heuristique a trouvé. Le contrôle de la section 3.4 est la seule
garantie, et il peut échouer sur une cause non encore identifiée.

**La calibration de `04-recherche` peut révéler que le scénario est trop long**
pour la CI. Repli acceptable : augmenter le budget de recherche du commandant
pour raccourcir l'aboutissement, au prix d'un scénario moins représentatif d'une
partie réelle.

## 10. Ordre de livraison

1. Mesurer le coût d'un tour. Conditionne le reste.
2. Lot 1, déterminisme : graine, date figée, maps à clé identitaire.
3. Lot 2, `Start dumpState`.
4. Lot 3, le harnais, validé sur `01-combat` seul.
5. Lot 4, les quatre scénarios restants.
6. Lot 5, le workflow, y compris le job témoin de déterminisme.
7. Section 8, la capture visuelle, après essai en local sur une sortie réelle.

Les étapes 4 et 5 sont volontairement séparées : le harnais se valide sur un
scénario avant qu'on paie cinq fois chacun de ses défauts.
