# Plan d'implémentation, harnais de non-régression du moteur

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** doter le moteur Sheril d'un harnais qui rejoue cinq scénarios connus à chaque PR et compare un dump d'état texte à une référence versionnée.

**Architecture:** trois couches indépendantes. (1) Le moteur devient reproductible, par une graine de générateur aléatoire lue dans `config.properties` et par la neutralisation des ordres de parcours arbitraires. (2) Une commande `Start dumpState` sérialise l'état objectif en texte trié, une donnée par ligne. (3) Un script shell générique déroule un dossier de scénario (SQL d'amorçage, ordres par tour, golden, assertions) et compare, sans jamais connaître le contenu du scénario.

**Tech Stack:** Java 21 (`javac` + `jar`, pas de Maven ni Gradle), MySQL 5 via `divers/base_sheril.sql`, bash, python3 pour la substitution de marqueurs, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-18-harnais-non-regression-moteur-design.md`

---

## Global Constraints

- **Périmètre moteur uniquement.** Java, PHP, SQL, scripts du repo. Jamais l'outillage Go de `~/perso/pbem/sheril`.
- **Aucun changement de comportement en production.** Toute nouvelle propriété (`RANDOM_SEED`, `DATE_FIGEE`) est facultative ; absente de `config.properties`, le moteur se comporte exactement comme aujourd'hui. `config.properties.sample` ne les déclare pas.
- **Java 21, sans dépendance nouvelle.** `libs/` contient `activation.jar`, `jakarta.mail-2.0.1.jar`, `mail.jar`, `mysql.jar`, `pircbot.jar`. Aucun jar n'est ajouté, aucun framework de test n'est introduit.
- **Build :** `scripts/create-jar.sh` depuis la racine du repo, produit `./sheril.jar`.
- **Exécution :** `java -cp sheril.jar Start <action>`, avec le répertoire courant contenant `config.properties` (`Univers.config`, `Univers.java:32`) et l'arborescence `data/` désignée par `PATH_DATA`.
- **Git :** branche puis PR vers le `main` d'`origin`. Jamais de PR vers `upstream`. Signature GPG obligatoire sur tous les commits. Chaque message de commit référence **`SHRL-46`**, ticket du chantier sur le tenant perso `sitael-pbem.atlassian.net` (`https://sitael-pbem.atlassian.net/browse/SHRL-46`). Il est en `To Do` : le passer en `In Progress` au démarrage de la tâche 1, ce qui déclenche aussi la création de son journal dans la base de connaissance.
- **Encodage :** tous les fichiers produits (dumps, goldens) en UTF-8, fins de ligne `\n`, séparateur décimal `.` (donc `String.format(Locale.ROOT, ...)` pour tout flottant).
- **Langue :** commentaires de code et messages en français, comme le reste du moteur.

---

## Écarts assumés par rapport à la spec

Trois points relevés à la lecture du code, à connaître avant d'exécuter.

**1. La spec sous-estime le lot 1 : deux `Collections.shuffle` non semés.**

- `AjoutDeGalaxie.java:58` : `java.util.Collections.shuffle(cellules)` répartit les 272 systèmes de la galaxie. Sur le chemin de `Start init`.
- `Univers.java:624` : `Collections.shuffle(restants)` dans `choisirPositionsDepartEquitables`, appelée par `ProductionOrdres.java:481` lors de la création des commandants. Sur le chemin de `Start newRound` quand un scénario inscrit ses joueurs.

La forme sans argument tire d'un `Random` interne à `Collections`, que `RANDOM_SEED` n'atteint pas. Sans correction, ni la galaxie ni les positions de départ ne sont reproductibles, et aucun golden ne tient. C'est traité en tâche 3.

**2. `AugmentationTaille.java` est du code mort, sa correction est retirée du plan.**

La spec (§3.1) demande de faire passer le `new Random()` de `AugmentationTaille.java:17` par `Univers.getInt`, au motif qu'il sert à l'ajout de galaxie. Vérification faite (`grep -rn "AugmentationTaille" sources/`), la classe n'est référencée nulle part : `Start.addNewGalaxy` appelle `AjoutDeGalaxie`, pas `AugmentationTaille`. Modifier du code injoignable ajoute du diff sans rien rendre reproductible, et la spec exclut explicitement les réécritures qui ne servent pas le déterminisme. Le point est donc documenté et non exécuté. Si l'utilisateur veut malgré tout la correction, elle tient en deux lignes et peut être livrée à part.

**3. L'ordre de livraison est modifié : `dumpState` passe avant le déterminisme.**

La spec (§10) place le lot 1 (déterminisme) avant le lot 2 (`dumpState`). Mais la seule façon d'écrire un test qui échoue pour le déterminisme est de comparer deux états, donc de disposer du dump. En livrant `dumpState` d'abord, chaque correction de déterminisme obtient un vrai cycle rouge puis vert. L'inversion ne change rien au contenu des deux lots ni à l'ordre des suivants.

Conséquence de cadrage : `03-marche` est écrit **avant** la correction du tri des enchères (tâche 8), pour que l'instabilité prédite en §3.3 de la spec soit constatée avant d'être corrigée, et non postulée.

---

## Structure des fichiers

**Créés**

| Fichier | Responsabilité |
|---|---|
| `sources/zIgzAg/jeu/oceane/DumpEtat.java` | Sérialisation texte canonique de l'état de l'univers. Aucune logique de jeu. |
| `test/harness/run-scenario.sh` | Déroule un scénario de bout en bout, compare au golden, évalue les assertions. Ignore le contenu des scénarios. |
| `test/harness/update-golden.sh` | Régénère les références d'un scénario. Seule voie de régénération. |
| `test/harness/check-determinisme.sh` | Rejoue deux fois le même scénario et compare les deux dumps entre eux, sans golden. |
| `test/harness/check-init-determinisme.sh` | Contrôle plus étroit et sans base de données : deux `Start init` semés, deux dumps, comparaison. |
| `test/harness/resolve-markers.py` | Substitue les marqueurs d'un fichier d'ordres depuis un dump. Échec fatal si un marqueur reste. |
| `test/harness/lib.sh` | Fonctions communes : préparation du répertoire de travail, écriture de `config.properties`, réinitialisation MySQL. |
| `test/scenarios/<nn>-<nom>/scenario.properties` | Graine, date figée, nombre de tours, description. |
| `test/scenarios/<nn>-<nom>/setup.sql` | Peuplement de `aa_inscription` et `aa_vaisseaux`. |
| `test/scenarios/<nn>-<nom>/turn-<n>.sql` | Ordres injectés avant le tour `n`. |
| `test/scenarios/<nn>-<nom>/assertions.txt` | Attentes minimales sur le dump final. |
| `test/scenarios/<nn>-<nom>/golden/dump-tour-<n>.txt` | Références versionnées. |
| `.github/workflows/harness.yml` | Jobs `build`, `scenarios`, `determinisme`, `rapports`, `captures`. |

**Modifiés**

| Fichier | Changement |
|---|---|
| `sources/Start.java` | Nouvelle action `dumpState`, ligne d'aide associée. |
| `sources/zIgzAg/jeu/oceane/Const.java` | Champs `RANDOM_SEED` et `DATE_FIGEE`, lus dans le bloc statique. |
| `sources/zIgzAg/jeu/oceane/Univers.java` | `Univers.java:1100`, instanciation semée de `HASARD`. `Univers.java:624`, `shuffle` semé. |
| `sources/zIgzAg/jeu/oceane/AjoutDeGalaxie.java` | Ligne 58, `shuffle` semé. |
| `sources/zIgzAg/jeu/oceane/Utile.java` | `getDateRapport()` retourne `Const.DATE_FIGEE` si elle est définie. |
| `sources/zIgzAg/jeu/oceane/PlanDeVaisseau.java` | Ligne 772, `LinkedHashMap`. |
| `sources/zIgzAg/jeu/oceane/RapportXML.java` | Ligne 556, `LinkedHashMap`. |
| `sources/zIgzAg/jeu/oceane/DataXML.java` | Ligne 253, `LinkedHashMap`. |
| `sources/zIgzAg/jeu/oceane/ReceptionOrdres.java` | `reglerEncheresMarche()`, tri des offres par `getId()` avant règlement. |
| `.gitignore` | Ignorer `test/work/`, répertoire de travail local du harnais. |

---

### Task 1: Mesurer le coût d'un tour

Aucune écriture de code. La spec (§9) fait dépendre tout le dimensionnement du harnais de ce chiffre inconnu.

**La mesure a été faite par la session `capture-rapports` le 2026-08-19**, dans un worktree isolé, sur Mac ARM avec `mysql:5` en émulation amd64 et un JDK temurin 21, chaque chiffre relevé deux fois sur base vierge.

| Poste | Durée |
|---|---|
| `docker compose up -d` jusqu'à MySQL joignable, 130 tables chargées | 10 s |
| `Start init` seul | 1,03 s puis 0,95 s |
| `Start addNewGalaxy 0` | 1,28 s puis 1,22 s |
| `scripts/init.sh` complet | environ 2,3 s de moteur |
| `Start newRound`, trois commandants | 2 s |
| Plancher d'un appel, JVM plus `docker compose exec`, mesuré sur `Start help` | 0,15 s |

La règle de décision du step 8 est donc satisfaite très largement, et le levier de repli de la spec (rendre `Const.NB_SECTEURS_X` et `Const.NB_SYSTEMES_PAR_SECTEUR` configurables) n'a pas lieu d'être ouvert. Cette tâche se réduit à confirmer l'ordre de grandeur sur la machine de référence et à consigner les deux séries.

Une réserve, telle que la session auteure la formule : ces chiffres viennent d'un Mac ARM où `mysql:5` tourne sous qemu, donc pénalisé, tandis que le CPU est plus rapide qu'un runner GitHub Actions. C'est un ordre de grandeur, pas une prévision de CI.

**Le harnais appelle `Start init`, jamais `scripts/init.sh`.** Le script d'amorçage lance `addNewGalaxy 0` deux fois, une fois dans `initUnivers()` (`Start.java:59`) et une fois en dernière ligne du script, ce qui double le nombre de systèmes et le coût. `run-scenario.sh` n'appelle que `Start init`, donc une seule galaxie de 272 systèmes pour environ 1 s. Ne pas « corriger » le harnais en le faisant passer par `init.sh`.

Note de dimensionnement : les 10 s de MySQL sont payées une fois par job, et la matrice de la tâche 10 donne un service par scénario, donc en parallèle. En local, jouer les cinq scénarios à la suite contre un stack unique coûte environ 10 s plus cinq fois le déroulé, et non cinq fois 10 s.

**Files:**
- Create: `docs/superpowers/mesures/2026-08-19-cout-tour-moteur.md`

**Interfaces:**
- Consumes: rien.
- Produces: le chiffre `SECONDES_PAR_TOUR` et la décision de rendre ou non `Const.NB_SECTEURS_X` et `Const.NB_SYSTEMES_PAR_SECTEUR` configurables. Les tâches 6 à 10 supposent qu'un tour tient sous 120 secondes ; au-delà, elles sont à revoir avant d'être exécutées.

- [ ] **Step 1: Démarrer la base de données**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
docker compose up -d db
docker compose exec -T db mysqladmin ping -ppassword
```

Attendu : `mysqld is alive`. La base écoute sur le port hôte `3311` (`docker-compose.yml`), et sur `db:3306` depuis le réseau compose.

- [ ] **Step 2: Construire le jar**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh
```

Attendu : `✅ sheril.jar JAR créé avec succès`, et `sheril.jar` présent à la racine.

- [ ] **Step 3: Préparer un univers neuf dans un répertoire de travail isolé**

Le moteur lit `config.properties` et `PATH_DATA` relativement au répertoire courant, ce qui permet d'isoler entièrement une exécution.

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
rm -rf test/work/mesure && mkdir -p test/work/mesure/data/commun test/work/mesure/php/rapports test/work/mesure/php/stats
cp -R data/fichiers test/work/mesure/data/fichiers
echo "0" > test/work/mesure/data/commun/tour.txt
cat > test/work/mesure/config.properties <<'EOF'
PATH_DATA = ./data/
PATH_EXPORT_ZIPPED_RAPPORT = ./rapports/
PATH_TOUR = ./data/commun/tour.txt
PATH_STATS = ./data/stats/
RACINE_SITE = http://localhost:666/
IRC_MAIN_CHANNEL = #sheril
SSH_PORT = 22
SSH_BASE_PATH = user@host:/vhosts/
DATABASE_HOST = 127.0.0.1:3311
DATABASE_LOGIN = user
DATABASE_PASSWORD = password
DATABASE_NAME = sheril
NOTIFY_BOT = false
FAKE_TURN = false
IS_LOCAL = true
PATH_PHP = ./php/
EOF
```

`NOTIFY_BOT` est obligatoire : `Const.java:64` fait `properties.getProperty("NOTIFY_BOT").equalsIgnoreCase("true")` et lève un `NullPointerException` si la clé manque.

- [ ] **Step 4: Charger le schéma dans une base vierge**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
docker compose exec -T db mysql -uroot -ppassword -e "DROP DATABASE IF EXISTS sheril; CREATE DATABASE sheril;"
docker compose exec -T db mysql -uroot -ppassword sheril < divers/base_sheril.sql
docker compose exec -T db mysql -uroot -ppassword sheril -e "SHOW TABLES;" | wc -l
```

Attendu : 126 lignes, soit les 125 tables du schéma plus l'en-tête.

- [ ] **Step 5: Mesurer `Start init`**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib/test/work/mesure
/usr/bin/time -p java -cp ../../../sheril.jar Start init
```

Attendu : `Fin génération carte HTML` puis trois lignes `real` / `user` / `sys`. Noter `real`. C'est la création de 272 systèmes et 272 flottes neutres (`Const.NB_SYSTEME` et `Const.NB_FLOTTE_NEUTRE`, `Const.java:95` et `:97`).

- [ ] **Step 6: Mesurer un tour à vide**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib/test/work/mesure
/usr/bin/time -p java -cp ../../../sheril.jar Start newRound
```

Attendu : le tour se déroule sans commandant humain, se termine par `Sauvegarde:`. Noter `real`. C'est le plancher : un tour réel avec des joueurs coûte davantage, à cause de la génération des rapports par commandant (`DeroulementDuTour.java:156-176`).

- [ ] **Step 7: Mesurer un tour avec deux commandants**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
docker compose exec -T db mysql -uroot -ppassword sheril -e "
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Alpha','alpha@test.local',0,0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Beta','beta@test.local',1,0);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('alpha@test.local',3,10);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('beta@test.local',3,10);"
cd test/work/mesure
/usr/bin/time -p java -cp ../../../sheril.jar Start newRound
/usr/bin/time -p java -cp ../../../sheril.jar Start newRound
```

Attendu : le premier `newRound` affiche `Creation du commandant Alpha` et `Creation du commandant Beta` ; le second déroule un tour à deux joueurs. Noter le `real` du second, c'est la mesure de référence.

- [ ] **Step 8: Consigner la mesure et trancher**

Écrire `docs/superpowers/mesures/2026-08-19-cout-tour-moteur.md` avec, dans cet ordre : la machine et la version de JDK (`java -version`), les quatre durées relevées localement, la série de la session `capture-rapports` reproduite en tête de tâche et son écart avec la mesure locale, l'extrapolation pour cinq scénarios de trois à six tours (soit dix-huit tours plus cinq `init`), et la décision.

Règle de décision, à appliquer telle quelle :

- Tour à deux joueurs sous 60 secondes : le harnais tient en CI tel qu'il est spécifié. Continuer à la tâche 2.
- Entre 60 et 180 secondes : continuer, mais la matrice GitHub de la tâche 10 devient obligatoire (elle l'est déjà) et `04-recherche` sera calibré au plus court.
- Au-delà de 180 secondes : ne pas continuer sans arbitrage. Le levier prévu par la spec est de rendre `Const.NB_SECTEURS_X` et `Const.NB_SYSTEMES_PAR_SECTEUR` configurables, valeurs de production par défaut. Ces deux champs sont `static final` (`Const.java:89` et `:91`) et lus par `AjoutDeGalaxie` et `Position` ; les rendre configurables est un chantier à part entière, à ouvrir comme tel.

- [ ] **Step 9: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add docs/superpowers/mesures/2026-08-19-cout-tour-moteur.md
git commit -m "docs(harnais): mesurer le coût d'un tour de moteur (SHRL-46)"
```

---

### Task 2: La commande `Start dumpState`

**Files:**
- Create: `sources/zIgzAg/jeu/oceane/DumpEtat.java`
- Modify: `sources/Start.java:15-53`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `DumpEtat.ecrire(String fichier, boolean complet) throws IOException`, écrit le dump texte.
  - Action CLI `java -cp sheril.jar Start dumpState <fichier> [--complet]`.
  - Le format de ligne `clé = valeur`, dont dépendent `resolve-markers.py` (tâche 6) et les assertions.

**Choix de format, à ne pas dévier**

Une donnée par ligne, `clé = valeur`, clés hiérarchiques séparées par des points, tri numérique à tous les niveaux. Les positions s'écrivent `g_y_x`, la forme rendue par `Position.toString()` (`Position.java:202`), pour rester substituables telles quelles dans les ordres SQL qui attendent une position (`Position.traduction`, `Position.java:209`).

Deux réductions par rapport à un dump exhaustif, sans lesquelles le golden dépasserait dix mille lignes :

- **Le commandant neutre (numéro 0) est résumé.** Il possède un système sur 272 et une flotte par système. Sont dumpés son nombre de possessions, et par flotte sa position et son nombre de vaisseaux. Cela suffit à détecter qu'un combat a détruit une flotte neutre.
- **Seules les planètes intéressantes sont détaillées**, c'est-à-dire celles qui ont un propriétaire (`getProprio() >= 0`) ou une population. Une planète colonisée apparaît donc au diff. Une régression qui modifierait une planète inhabitée reste invisible, c'est le prix assumé de la lisibilité.

`--complet` désactive les deux réductions, pour le diagnostic hors CI.

- [ ] **Step 1: Écrire le test qui échoue**

Le moteur n'a pas de framework de test et le plan n'en introduit pas. Le test est un script qui appelle la commande et vérifie la forme de sa sortie.

Créer `test/harness/check-dumpstate.sh` :

```bash
#!/usr/bin/env bash
# Contrôle minimal de Start dumpState : la commande existe, produit un fichier
# non vide, trié, et contenant les sections attendues.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO/test/work/dumpstate"

rm -rf "$WORK"
mkdir -p "$WORK/data/commun" "$WORK/php/rapports" "$WORK/php/stats"
cp -R "$REPO/data/fichiers" "$WORK/data/fichiers"
echo "0" > "$WORK/data/commun/tour.txt"
sed -e 's|^DATABASE_HOST.*|DATABASE_HOST = 127.0.0.1:3311|' \
    -e 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' \
    "$REPO/config.properties.sample" > "$WORK/config.properties"

cd "$WORK"
java -cp "$REPO/sheril.jar" Start init > init.log 2>&1
java -cp "$REPO/sheril.jar" Start dumpState dump.txt

test -s dump.txt || { echo "ECHEC: dump.txt vide ou absent"; exit 1; }

for cle in "tour = " "commandant.0.nom = " "commandant.0.flottes = " "systeme."; do
  grep -q "^$cle" dump.txt || { echo "ECHEC: section manquante: $cle"; exit 1; }
done

# Toute ligne non vide doit avoir la forme "cle = valeur". La clé n'est pas
# contrainte à un jeu de caractères : un nom de plan de vaisseau contient une
# espace ("Chasseur standard"), et il apparaît dans la clé
# commandant.<n>.flotte.<f>.vaisseau.<type>.
if grep -vE '^[^=]+ = ' dump.txt | grep -q .; then
  echo "ECHEC: lignes hors format 'cle = valeur'"
  grep -vnE '^[^=]+ = ' dump.txt | head
  exit 1
fi

echo "OK: $(wc -l < dump.txt) lignes"
```

```bash
chmod +x test/harness/check-dumpstate.sh
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh && ./test/harness/check-dumpstate.sh
```

Attendu : ÉCHEC. `Start dumpState` n'existe pas, le moteur affiche `Vous devez spécifier au moins un paramètre` suivi de l'aide, `dump.txt` n'est pas créé, le script sort sur `ECHEC: dump.txt vide ou absent`.

- [ ] **Step 3: Écrire `DumpEtat`**

Créer `sources/zIgzAg/jeu/oceane/DumpEtat.java` :

```java
// Sérialisation texte canonique de l'état de l'univers.
// Sert de référence de non-régression et d'outil de diagnostic.
// Aucune logique de jeu ici : cette classe lit, elle ne modifie rien.

package zIgzAg.jeu.oceane;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class DumpEtat {

	private static final Comparator<Position> PAR_POSITION = new Comparator<Position>() {
		public int compare(Position a, Position b) {
			int r = Integer.compare(a.getNumeroGalaxie(), b.getNumeroGalaxie());
			if (r != 0)
				return r;
			r = Integer.compare(a.getY(), b.getY());
			if (r != 0)
				return r;
			return Integer.compare(a.getX(), b.getX());
		}
	};

	private DumpEtat() {
	}

	public static void ecrire(String fichier, boolean complet) throws IOException {
		new Univers(true, "dumpState");
		StringBuilder sb = new StringBuilder();
		sb.append("tour = ").append(Univers.getTour()).append('\n');
		ecrireCommandants(sb, complet);
		ecrireSystemes(sb, complet);
		ecrireAlliances(sb);
		ecrireMarche(sb);
		Files.write(Paths.get(fichier), sb.toString().getBytes(StandardCharsets.UTF_8));
	}

	// un flottant se formate toujours en Locale.ROOT, sinon la virgule
	// décimale de la locale française rendrait le dump dépendant de
	// l'environnement.
	private static String f(float valeur) {
		return String.format(Locale.ROOT, "%.2f", valeur);
	}

	private static String pos(Position p) {
		return (p == null) ? "-" : p.toString();
	}

	private static void ecrireCommandants(StringBuilder sb, boolean complet) {
		Commandant[] cs = Univers.getListeCommandants();
		Arrays.sort(cs, new Comparator<Commandant>() {
			public int compare(Commandant a, Commandant b) {
				return Integer.compare(a.getNumero(), b.getNumero());
			}
		});
		for (int i = 0; i < cs.length; i++) {
			Commandant c = cs[i];
			boolean resume = !complet && (c.getNumero() == 0);
			String p = "commandant." + c.getNumero();
			sb.append(p).append(".nom = ").append(c.getNom()).append('\n');
			sb.append(p).append(".race = ").append(c.getRace()).append('\n');
			sb.append(p).append(".humain = ").append(c.estJoueurHumain()).append('\n');
			sb.append(p).append(".centaures = ").append(f(c.getCentaures())).append('\n');
			sb.append(p).append(".reputation = ").append(c.getReputation()).append('\n');
			sb.append(p).append(".pointsDeVictoire = ").append(c.getPointsDeVictoire()).append('\n');
			sb.append(p).append(".capitale = ").append(pos(c.getCapitale())).append('\n');
			sb.append(p).append(".possessions = ").append(c.getNombrePossessions()).append('\n');
			sb.append(p).append(".flottes = ").append(c.getNombreDeFlottes()).append('\n');

			if (!resume) {
				String[] technos = c.listeTechnologiesNonPubliquesConnues();
				Arrays.sort(technos);
				sb.append(p).append(".technologies = ").append(String.join(",", technos)).append('\n');

				String[] recherches = c.recherchesActuelles();
				Arrays.sort(recherches);
				for (int j = 0; j < recherches.length; j++) {
					String code = recherches[j];
					sb.append(p).append(".recherche.").append(code).append(" = ")
							.append(c.pourcentageAffecte(code)).append('/')
							.append(c.nombreDePointsDeRecherche(code)).append('\n');
				}

				Position[] domaine = c.listePossession();
				Arrays.sort(domaine, PAR_POSITION);
				for (int j = 0; j < domaine.length; j++)
					ecrirePossession(sb, p, domaine[j], c.getPossession(domaine[j]));
			}

			ecrireFlottes(sb, p, c, resume);
		}
	}

	private static void ecrirePossession(StringBuilder sb, String p, Position pos, Possession poss) {
		String q = p + ".possession." + pos(pos);
		sb.append(q).append(".politique = ").append(poss.getPolitique()).append('\n');
		for (int d = 0; d < Const.NB_DOMAINES_BUDGET; d++)
			sb.append(q).append(".budget.").append(d).append(" = ").append(poss.getBudget(d)).append('\n');
		int[] marchandises = poss.listeNumerosMarchandises();
		Arrays.sort(marchandises);
		for (int k = 0; k < marchandises.length; k++) {
			int m = marchandises[k];
			sb.append(q).append(".marchandise.").append(m).append(" = ")
					.append(poss.getPrixMarchandise(m)).append('/')
					.append(poss.getQuantiteMarchandise(m)).append('\n');
		}
	}

	private static void ecrireFlottes(StringBuilder sb, String p, Commandant c, boolean resume) {
		Map.Entry<Integer, Flotte>[] flottes = c.listeFlottesEtNumeros();
		Arrays.sort(flottes, new Comparator<Map.Entry<Integer, Flotte>>() {
			public int compare(Map.Entry<Integer, Flotte> a, Map.Entry<Integer, Flotte> b) {
				return Integer.compare(a.getKey(), b.getKey());
			}
		});
		for (int j = 0; j < flottes.length; j++) {
			Flotte fl = flottes[j].getValue();
			String q = p + ".flotte." + flottes[j].getKey();
			sb.append(q).append(".position = ").append(pos(fl.getPosition())).append('\n');
			sb.append(q).append(".vaisseaux = ").append(fl.getNombreDeVaisseaux()).append('\n');
			if (resume)
				continue;
			sb.append(q).append(".nom = ").append(fl.getNom()).append('\n');
			sb.append(q).append(".direction = ").append(pos(fl.getDirection())).append('\n');
			sb.append(q).append(".directive = ").append(fl.getDirectiveComplete()).append('\n');
			sb.append(q).append(".strategie = ").append(fl.getStrategie()).append('\n');
			sb.append(q).append(".puissance = ").append(fl.getPuissance()).append('\n');
			Map.Entry<String, Integer>[] types = fl.listeVaisseauxParType();
			Arrays.sort(types, new Comparator<Map.Entry<String, Integer>>() {
				public int compare(Map.Entry<String, Integer> a, Map.Entry<String, Integer> b) {
					return a.getKey().compareTo(b.getKey());
				}
			});
			for (int k = 0; k < types.length; k++)
				sb.append(q).append(".vaisseau.").append(types[k].getKey()).append(" = ")
						.append(types[k].getValue()).append('\n');
		}
	}

	private static void ecrireSystemes(StringBuilder sb, boolean complet) {
		Position[] positions = Univers.listePositionsSystemes();
		Arrays.sort(positions, PAR_POSITION);
		for (int i = 0; i < positions.length; i++) {
			Systeme s = Univers.getSysteme(positions[i]);
			String p = "systeme." + pos(positions[i]);
			sb.append(p).append(".nom = ").append(s.getNom()).append('\n');
			sb.append(p).append(".etoile = ").append(s.getTypeEtoile()).append('\n');
			int[] proprios = s.getProprios();
			Arrays.sort(proprios);
			StringBuilder liste = new StringBuilder();
			for (int j = 0; j < proprios.length; j++) {
				if (j > 0)
					liste.append(',');
				liste.append(proprios[j]);
			}
			sb.append(p).append(".proprios = ").append(liste).append('\n');
			for (int j = 0; j < proprios.length; j++) {
				sb.append(p).append(".proprio.").append(proprios[j]).append(".minerai = ")
						.append(s.getStockMinerai(proprios[j])).append('\n');
				sb.append(p).append(".proprio.").append(proprios[j]).append(".population = ")
						.append(s.getPopulation(proprios[j])).append('\n');
				sb.append(p).append(".proprio.").append(proprios[j]).append(".taxation = ")
						.append(s.getTaxation(proprios[j])).append('\n');
			}
			Planete[] planetes = s.getPlanetes();
			for (int j = 0; j < planetes.length; j++)
				ecrirePlanete(sb, p, j, planetes[j], complet);
		}
	}

	private static void ecrirePlanete(StringBuilder sb, String p, int index, Planete pl, boolean complet) {
		boolean interessante = (pl.getProprio() >= 0) || pl.estHabite();
		if (!complet && !interessante)
			return;
		String q = p + ".planete." + index;
		sb.append(q).append(".nom = ").append(pl.getNom()).append('\n');
		sb.append(q).append(".proprio = ").append(pl.getProprio()).append('\n');
		sb.append(q).append(".taille = ").append(pl.getTaille()).append('\n');
		sb.append(q).append(".type = ").append(pl.getType()).append('\n');
		sb.append(q).append(".terraformation = ").append(pl.getTerraformation()).append('\n');
		sb.append(q).append(".minerai = ").append(pl.getStockMinerai()).append('\n');
		sb.append(q).append(".taxation = ").append(pl.getTaxation()).append('\n');
		sb.append(q).append(".stabilite = ").append(pl.getStabilite()).append('\n');
		sb.append(q).append(".revolte = ").append(pl.getRevolte()).append('\n');
		for (int race = 0; race < Const.NB_RACES; race++) {
			int pop = pl.getPopActuelle(race);
			if (pop > 0)
				sb.append(q).append(".population.").append(race).append(" = ").append(pop).append('\n');
		}
	}

	private static void ecrireAlliances(StringBuilder sb) {
		Alliance[] as = Univers.getListeAlliances();
		Arrays.sort(as, new Comparator<Alliance>() {
			public int compare(Alliance a, Alliance b) {
				return Integer.compare(a.getNumero(), b.getNumero());
			}
		});
		for (int i = 0; i < as.length; i++) {
			Alliance a = as[i];
			String p = "alliance." + a.getNumero();
			sb.append(p).append(".nom = ").append(a.getNom()).append('\n');
			sb.append(p).append(".secrete = ").append(a.estSecrete()).append('\n');
			sb.append(p).append(".type = ").append(a.getDescriptionType(Locale.FRENCH)).append('\n');
			sb.append(p).append(".droits = ").append(f(a.getDroitsEntree())).append('\n');
			sb.append(p).append(".concepteur = ").append(a.getNumeroConcepteur()).append('\n');
			sb.append(p).append(".dirigeant = ").append(a.getNumeroDirigeant()).append('\n');
			Commandant[] membres = a.getAdherents();
			List<Integer> nums = new ArrayList<Integer>(membres.length);
			for (int j = 0; j < membres.length; j++)
				nums.add(membres[j].getNumero());
			java.util.Collections.sort(nums);
			StringBuilder liste = new StringBuilder();
			for (int j = 0; j < nums.size(); j++) {
				if (j > 0)
					liste.append(',');
				liste.append(nums.get(j));
			}
			sb.append(p).append(".membres = ").append(liste).append('\n');
		}
	}

	private static void ecrireMarche(StringBuilder sb) {
		List<OffreMarche> offres = new ArrayList<OffreMarche>(Univers.getListeOffresMarche());
		java.util.Collections.sort(offres, new Comparator<OffreMarche>() {
			public int compare(OffreMarche a, OffreMarche b) {
				return Integer.compare(a.getId(), b.getId());
			}
		});
		for (int i = 0; i < offres.size(); i++) {
			OffreMarche o = offres.get(i);
			String p = "offre." + o.getId();
			sb.append(p).append(".vendeur = ").append(o.getNumeroVendeur()).append('\n');
			sb.append(p).append(".origine = ").append(pos(o.getPositionOrigine())).append('\n');
			sb.append(p).append(".code = ").append(o.getCodeMarchandise()).append('\n');
			sb.append(p).append(".quantite = ").append(o.getQuantite()).append('\n');
			sb.append(p).append(".prix = ").append(o.getPrixTotal()).append('\n');
			sb.append(p).append(".tourFin = ").append(o.getTourFin()).append('\n');
		}
	}
}
```

- [ ] **Step 4: Câbler l'action dans `Start`**

Dans `sources/Start.java`, ajouter la ligne d'aide après `listNeutralFleets` (`Start.java:21`) :

```java
        System.out.println("dumpState <fichier> [--complet]: écrit l'état de l'univers en texte");
```

et la branche, avant le `else` final de `main` (`Start.java:46`) :

```java
        } else if (args[0].equals("dumpState")) {
            if (args.length < 2) {
                System.out.println("Il faut spécifier le fichier de sortie");
                displayHelp();
                System.exit(-1);
            }
            boolean complet = (args.length > 2) && args[2].equals("--complet");
            try {
                DumpEtat.ecrire(args[1], complet);
            } catch (IOException e) {
                System.out.println("Erreur d'écriture du dump " + args[1]);
                e.printStackTrace();
                System.exit(-1);
            }
```

`java.io.IOException` est déjà importé (`Start.java:2`), `zIgzAg.jeu.oceane.*` aussi (`Start.java:10`).

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh && ./test/harness/check-dumpstate.sh
```

Attendu : `OK: <n> lignes`, avec `n` de l'ordre de 1500 à 2500 pour un univers fraîchement initialisé.

- [ ] **Step 6: Vérifier à l'œil ce que produit le dump**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
head -40 test/work/dumpstate/dump.txt
grep -c '^systeme\.' test/work/dumpstate/dump.txt
```

Attendu : les 272 systèmes présents, le commandant `neutre` en numéro 0, aucune ligne avec une virgule décimale.

- [ ] **Step 7: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add sources/zIgzAg/jeu/oceane/DumpEtat.java sources/Start.java test/harness/check-dumpstate.sh
git commit -m "feat(moteur): ajouter Start dumpState, dump texte canonique de l'état (SHRL-46)"
```

---

### Task 3: Semer tout le hasard

**Files:**
- Modify: `sources/zIgzAg/jeu/oceane/Const.java:36-76`
- Modify: `sources/zIgzAg/jeu/oceane/Univers.java:1100`, `sources/zIgzAg/jeu/oceane/Univers.java:624`
- Modify: `sources/zIgzAg/jeu/oceane/AjoutDeGalaxie.java:58`
- Create: `test/harness/check-init-determinisme.sh`

**Interfaces:**
- Consumes: `DumpEtat.ecrire` et l'action `Start dumpState` de la tâche 2.
- Produces:
  - `Const.RANDOM_SEED`, de type `Long`, `null` quand la propriété est absente.
  - `Univers.getHasard()`, accesseur `public static Random` sur le générateur unique, nécessaire pour semer les deux `Collections.shuffle`.
  - `test/harness/check-init-determinisme.sh`, réutilisé tel quel par le job `determinisme` de la tâche 10.

**Le défaut est constaté, pas seulement déduit.** La session `capture-rapports` a snapshoté l'état complet (`mysqldump` plus archive de `data/`), joué le tour 2, restauré l'état à l'identique, rejoué le même tour 2, et comparé les deux sorties page à page : 15 pages sur 21 identiques au bit près, mais `principal.htm` et `detailF.htm` divergent pour les trois commandants. Ce qui bouge est tiré au hasard à chaque exécution, noms de vaisseaux (`Loeye` contre `Reqiw`), dommages et composants détruits (`0/5` contre `1/5`), et jusqu'à des valeurs de jeu, Puissance `40277` contre `40116`, Réputation `0` contre `9`. Ce sont les consommateurs de `Univers.getInt` (`Univers.java:355`), `getTabInt` (`:359`) et `getBoolean` (`:366`), tous alimentés par le `HASARD` instancié sans graine en `Univers.java:1100`. La correction ci-dessous vise exactement cette source.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/harness/check-init-determinisme.sh` :

```bash
#!/usr/bin/env bash
# Deux "Start init" avec la même graine doivent produire le même état.
# Ce contrôle ne dépend d'aucun golden ni d'aucune base de données.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED="${SEED:-424242}"
DB_HOST="${DB_HOST:-127.0.0.1:3311}"

init_une_fois() {
  local work="$1"
  rm -rf "$work"
  mkdir -p "$work/data/commun" "$work/php/rapports" "$work/php/stats"
  cp -R "$REPO/data/fichiers" "$work/data/fichiers"
  echo "0" > "$work/data/commun/tour.txt"
  {
    sed -e 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' \
        -e "s|^DATABASE_HOST.*|DATABASE_HOST = $DB_HOST|" \
        "$REPO/config.properties.sample"
    echo ""
    echo "RANDOM_SEED = $SEED"
  } > "$work/config.properties"
  ( cd "$work" && java -cp "$REPO/sheril.jar" Start init > init.log 2>&1 )
  ( cd "$work" && java -cp "$REPO/sheril.jar" Start dumpState dump.txt )
}

init_une_fois "$REPO/test/work/init-a"
init_une_fois "$REPO/test/work/init-b"

if /usr/bin/diff -u "$REPO/test/work/init-a/dump.txt" "$REPO/test/work/init-b/dump.txt" > "$REPO/test/work/init-diff.txt"; then
  echo "OK: deux init avec la graine $SEED donnent le même état"
else
  echo "ECHEC: les deux init divergent, extrait du diff:"
  head -40 "$REPO/test/work/init-diff.txt"
  exit 1
fi
```

```bash
chmod +x test/harness/check-init-determinisme.sh
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-init-determinisme.sh
```

Attendu : ÉCHEC. `RANDOM_SEED` n'est pas encore lue, chaque `init` tire son propre `new Random()` (`Univers.java:1100`), et les 272 systèmes ne tombent pas aux mêmes positions. Le diff est massif.

- [ ] **Step 3: Déclarer `RANDOM_SEED` dans `Const`**

Ajouter le champ auprès des autres, après `PATH_PHP` (`Const.java:34`) :

```java
    /** Graine du générateur aléatoire. null = comportement de production. */
    public static Long RANDOM_SEED = null;
```

et la lecture dans le bloc statique, avant la fermeture du `try` (`Const.java:70`) :

```java
            String seedProp = properties.getProperty("RANDOM_SEED");
            if (seedProp != null && !seedProp.trim().isEmpty()) {
              RANDOM_SEED = Long.valueOf(seedProp.trim());
            }
```

- [ ] **Step 4: Semer le générateur unique**

Dans `sources/zIgzAg/jeu/oceane/Univers.java`, remplacer la ligne 1100 :

```java
		HASARD = new Random();
```

par :

```java
		HASARD = (Const.RANDOM_SEED == null) ? new Random() : new Random(Const.RANDOM_SEED);
```

et ajouter, à côté de `getInt` (`Univers.java:355`), l'accesseur dont les deux `shuffle` ont besoin :

```java
	// Le générateur unique de l'univers. Exposé pour que les mélanges de
	// collections tirent de la même source que le reste du hasard, donc
	// de la graine quand elle est fixée.
	public static Random getHasard() {
		return HASARD;
	}
```

- [ ] **Step 5: Semer le mélange des positions de départ**

Dans `sources/zIgzAg/jeu/oceane/Univers.java:624`, remplacer :

```java
		Collections.shuffle(restants);
```

par :

```java
		Collections.shuffle(restants, getHasard());
```

Sans cela, `choisirPositionsDepartEquitables` place les commandants d'un scénario à des endroits différents à chaque exécution. Elle est appelée par `ProductionOrdres.java:481`, sur le chemin de création des commandants.

- [ ] **Step 6: Semer le mélange des cellules de la galaxie**

Dans `sources/zIgzAg/jeu/oceane/AjoutDeGalaxie.java:58`, remplacer :

```java
        java.util.Collections.shuffle(cellules);
```

par :

```java
        java.util.Collections.shuffle(cellules, Univers.getHasard());
```

C'est ce mélange qui décide où tombent les 272 systèmes.

- [ ] **Step 7: Lancer le test et vérifier qu'il passe**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh && ./test/harness/check-init-determinisme.sh
```

Attendu : `OK: deux init avec la graine 424242 donnent le même état`.

- [ ] **Step 8: Vérifier que deux graines différentes donnent bien deux univers différents**

Ce contrôle évite le faux positif où la graine ne serait pas lue du tout et où les deux exécutions coïncideraient pour une autre raison.

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
SEED=111 ./test/harness/check-init-determinisme.sh
cp test/work/init-a/dump.txt test/work/dump-seed-111.txt
SEED=222 ./test/harness/check-init-determinisme.sh
/usr/bin/diff -q test/work/dump-seed-111.txt test/work/init-a/dump.txt || echo "OK: graines différentes, univers différents"
```

Attendu : les deux lancements passent, et la comparaison finale imprime `OK: graines différentes, univers différents`.

- [ ] **Step 9: Vérifier que la production n'est pas touchée**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
grep -c RANDOM_SEED config.properties.sample
```

Attendu : `0`. La propriété reste absente du fichier d'exemple, donc `Const.RANDOM_SEED` vaut `null` et le moteur tire au hasard comme avant.

- [ ] **Step 10: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add sources/zIgzAg/jeu/oceane/Const.java sources/zIgzAg/jeu/oceane/Univers.java \
        sources/zIgzAg/jeu/oceane/AjoutDeGalaxie.java test/harness/check-init-determinisme.sh
git commit -m "feat(moteur): semer le générateur aléatoire par RANDOM_SEED (SHRL-46)"
```

---

### Task 4: Figer la date des rapports

**Files:**
- Modify: `sources/zIgzAg/jeu/oceane/Const.java`
- Modify: `sources/zIgzAg/jeu/oceane/Utile.java:218-226`

**Interfaces:**
- Consumes: le motif de lecture de propriété facultative introduit en tâche 3.
- Produces: `Const.DATE_FIGEE`, `String`, `null` quand la propriété est absente. Consommée par `Utile.getDateRapport()`, dont l'unique appelant est `Rapport.java:1297`.

Ce point ne sert pas le golden, qui ne compare pas le HTML. Il est ici parce qu'il est gratuit une fois qu'on touche à ce groupe de réglages, et parce qu'il rend comparables les captures de la tâche 11.

- [ ] **Step 1: Écrire le test qui échoue**

`jshell` permet d'appeler la méthode sans introduire de framework de test.

Créer `test/harness/check-date-figee.sh` :

```bash
#!/usr/bin/env bash
# Quand DATE_FIGEE est présente dans config.properties, Utile.getDateRapport
# doit la retourner telle quelle. Quand elle est absente, la date du jour.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO/test/work/date-figee"
rm -rf "$WORK" && mkdir -p "$WORK"

appel() {
  ( cd "$WORK" && echo 'System.out.println(zIgzAg.jeu.oceane.Utile.getDateRapport());' \
      | jshell --class-path "$REPO/sheril.jar" -s - 2>/dev/null | tr -d '\r' | grep -E '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' )
}

sed 's|^NOTIFY_BOT.*|NOTIFY_BOT = false|' "$REPO/config.properties.sample" > "$WORK/config.properties"
sans=$(appel)
attendu_sans=$(date +%d/%m/%Y)
test "$sans" = "$attendu_sans" || { echo "ECHEC: sans DATE_FIGEE, obtenu '$sans', attendu '$attendu_sans'"; exit 1; }

printf '\nDATE_FIGEE = 01/01/2000\n' >> "$WORK/config.properties"
avec=$(appel)
test "$avec" = "01/01/2000" || { echo "ECHEC: avec DATE_FIGEE, obtenu '$avec', attendu '01/01/2000'"; exit 1; }

echo "OK: DATE_FIGEE respectée, et absente le comportement est inchangé"
```

```bash
chmod +x test/harness/check-date-figee.sh
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-date-figee.sh
```

Attendu : ÉCHEC sur la seconde assertion, `obtenu '<date du jour>', attendu '01/01/2000'`. La première assertion passe déjà.

- [ ] **Step 3: Déclarer `DATE_FIGEE` dans `Const`**

Sous `RANDOM_SEED` :

```java
    /** Date affichée dans les rapports, au format JJ/MM/AAAA. null = date du jour. */
    public static String DATE_FIGEE = null;
```

et dans le bloc statique, sous la lecture de `RANDOM_SEED` :

```java
            String dateProp = properties.getProperty("DATE_FIGEE");
            if (dateProp != null && !dateProp.trim().isEmpty()) {
              DATE_FIGEE = dateProp.trim();
            }
```

- [ ] **Step 4: Retourner la date figée quand elle est définie**

Dans `sources/zIgzAg/jeu/oceane/Utile.java:218`, en tête de `getDateRapport()` :

```java
	public static String getDateRapport() {
		if (Const.DATE_FIGEE != null)
			return Const.DATE_FIGEE;
		GregorianCalendar gc = new GregorianCalendar();
```

Le reste du corps est inchangé.

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh && ./test/harness/check-date-figee.sh
```

Attendu : `OK: DATE_FIGEE respectée, et absente le comportement est inchangé`.

- [ ] **Step 6: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add sources/zIgzAg/jeu/oceane/Const.java sources/zIgzAg/jeu/oceane/Utile.java test/harness/check-date-figee.sh
git commit -m "feat(moteur): figer la date des rapports par DATE_FIGEE (SHRL-46)"
```

---

### Task 5: Ordonner les composants de vaisseau

**Files:**
- Modify: `sources/zIgzAg/jeu/oceane/PlanDeVaisseau.java:772`
- Modify: `sources/zIgzAg/jeu/oceane/RapportXML.java:556`
- Modify: `sources/zIgzAg/jeu/oceane/DataXML.java:253`
- Create: `test/harness/check-composants-determinisme.sh`

**Interfaces:**
- Consumes: `Start init` semé de la tâche 3.
- Produces: rien de nouveau pour les tâches suivantes. La sortie de `PlanDeVaisseau.descriptionComposants(ComposantDeVaisseau[], Locale)` devient stable d'une JVM à l'autre.

`ComposantDeVaisseau` (`ComposantDeVaisseau.java:7`) n'override ni `equals` ni `hashCode`. Les trois `HashMap<ComposantDeVaisseau, Integer>` sont donc hachées par identité mémoire, et l'ordre de `entrySet()` change d'une exécution de JVM à l'autre. Passer en `LinkedHashMap` conserve exactement la sémantique d'identité et fixe l'ordre sur celui de l'insertion, qui est celui du tableau `getComposants()`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/harness/check-composants-determinisme.sh` :

```bash
#!/usr/bin/env bash
# La description des composants d'un plan doit être identique d'une JVM à l'autre.
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

if /usr/bin/diff -u "$WORK/a.txt" "$WORK/b.txt" > "$WORK/diff.txt"; then
  echo "OK: $(wc -l < "$WORK/a.txt") plans décrits à l'identique dans deux JVM"
else
  echo "ECHEC: la description des composants varie d'une JVM à l'autre:"
  head -20 "$WORK/diff.txt"
  exit 1
fi
```

```bash
chmod +x test/harness/check-composants-determinisme.sh
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-composants-determinisme.sh
```

Attendu : ÉCHEC, avec un diff sur l'ordre des composants d'au moins un plan multi-composants (les plans `Destroyer standard`, `Croiseur standard` et `Supercroiseur standard` en ont trois ou plus, `Univers.java` liste `PLAN_DEPART`).

Si le test passe du premier coup, ne pas modifier le code : le relancer cinq fois d'affilée. L'ordre d'itération d'une `HashMap` à clés identitaires dépend des adresses attribuées par la JVM, une coïncidence sur deux exécutions est possible. S'il passe cinq fois, l'analyse est à revoir avant de continuer, et le noter dans le journal du ticket.

- [ ] **Step 3: Passer les trois maps en `LinkedHashMap`**

Dans `sources/zIgzAg/jeu/oceane/PlanDeVaisseau.java:772` :

```java
		HashMap<ComposantDeVaisseau, Integer> hm = new LinkedHashMap<>(c.length);
```

Dans `sources/zIgzAg/jeu/oceane/RapportXML.java:556` et `sources/zIgzAg/jeu/oceane/DataXML.java:253`, la même substitution, ligne pour ligne.

Ajouter `import java.util.LinkedHashMap;` dans les trois fichiers si l'import `java.util.*` n'y est pas déjà. Vérifier avec :

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
grep -n "^import java.util" sources/zIgzAg/jeu/oceane/PlanDeVaisseau.java \
     sources/zIgzAg/jeu/oceane/RapportXML.java sources/zIgzAg/jeu/oceane/DataXML.java
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh && ./test/harness/check-composants-determinisme.sh
```

Attendu : `OK: <n> plans décrits à l'identique dans deux JVM`. Le relancer trois fois pour écarter la coïncidence.

- [ ] **Step 5: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add sources/zIgzAg/jeu/oceane/PlanDeVaisseau.java sources/zIgzAg/jeu/oceane/RapportXML.java \
        sources/zIgzAg/jeu/oceane/DataXML.java test/harness/check-composants-determinisme.sh
git commit -m "fix(moteur): fixer l'ordre des composants de vaisseau (LinkedHashMap) (SHRL-46)"
```

---

### Task 6: Le harnais, validé sur `01-combat`

C'est la tâche la plus lourde du plan. Elle livre les quatre scripts du harnais et le premier scénario, et rien de plus : les quatre autres scénarios attendent que ce socle soit vert.

**Files:**
- Create: `test/harness/lib.sh`
- Create: `test/harness/resolve-markers.py`
- Create: `test/harness/run-scenario.sh`
- Create: `test/harness/update-golden.sh`
- Create: `test/harness/check-determinisme.sh`
- Create: `test/scenarios/01-combat/scenario.properties`
- Create: `test/scenarios/01-combat/setup.sql`
- Create: `test/scenarios/01-combat/turn-1.sql`
- Create: `test/scenarios/01-combat/turn-2.sql`
- Create: `test/scenarios/01-combat/assertions.txt`
- Create: `test/scenarios/01-combat/golden/dump-tour-1.txt`, `dump-tour-2.txt`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `Start dumpState` (tâche 2), `RANDOM_SEED` et `DATE_FIGEE` (tâches 3 et 4).
- Produces:
  - `test/harness/run-scenario.sh <scenario>`, code retour 0 si le dump de chaque tour est identique à son golden et si toutes les assertions passent.
  - `test/harness/update-golden.sh <scenario>`, régénère `golden/dump-tour-<n>.txt`.
  - `test/harness/check-determinisme.sh <scenario>`, rejoue deux fois et compare les dumps entre eux.
  - Variables d'environnement lues par les trois : `MYSQL_CLI` (par défaut `docker compose exec -T db mysql`), `DB_HOST` (par défaut `127.0.0.1:3311`).
  - La convention de marqueurs, consommée par les tâches 7, 8 et 9.

**Les marqueurs**

Un ordre référence un numéro de commandant, un numéro de flotte, une position de capitale, un identifiant d'offre. Toutes ces valeurs sont attribuées par le moteur et inconnues à l'écriture du scénario. Les écrire en dur marche tant que la graine ne bouge pas, puis, le jour où la numérotation se décale, les ordres pointent dans le vide, le moteur les ignore en silence, et `update-golden.sh` entérine un golden où plus rien ne se passe.

Les fichiers d'ordres écrivent donc des marqueurs, résolus depuis le dump du tour précédent. Ils sont indexés par le **nom du commandant**, qui est la seule donnée que le scénario choisit lui-même.

| Marqueur | Résolution | Exemple rendu |
|---|---|---|
| `@NUM(Alpha)@` | numéro du commandant nommé `Alpha` | `1` |
| `@CAP(Alpha)@` | position de sa capitale, forme `g_y_x` | `0_12_7` |
| `@CAPG(Alpha)@` | galaxie de sa capitale | `0` |
| `@CAPY(Alpha)@` | ordonnée de sa capitale | `12` |
| `@CAPX(Alpha)@` | abscisse de sa capitale | `7` |
| `@FLOTTE(Alpha,0)@` | numéro de sa flotte de rang 0, flottes triées par numéro croissant | `0` |
| `@OFFRE(Alpha,0)@` | identifiant de son offre de marché de rang 0, offres triées par identifiant | `1` |

Un marqueur non résolu est une erreur fatale, jamais un avertissement.

**Pourquoi les commandants naissent d'un `INSERT` et non d'une commande.** `Start` n'expose que `init`, `addNewGalaxy`, `newRound`, `listFleet` et `help` (`Start.java:33-51`) : aucune sous-commande ne crée un commandant. La console PHP le fait par un `POST` sur `register.php`, qui se réduit à un `INSERT` dans `aa_inscription`, consommé au tour suivant par `ProductionOrdres.produireRegistre` (`ProductionOrdres.java:407`, création en `:503`). Le harnais écrit donc directement dans `aa_inscription` et `aa_vaisseaux`, ce qui donne exactement le même état sans dépendre du conteneur Apache ni du PHP, tous deux hors périmètre. Point vérifié par la session `capture-rapports` en montant le stack complet.

- [ ] **Step 1: Écrire les fonctions communes**

Créer `test/harness/lib.sh` :

```bash
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
```

`propriete` utilise `cut` et `xargs` : c'est du shell exécuté par le harnais, pas une lecture de fichier par l'agent.

- [ ] **Step 2: Écrire le résolveur de marqueurs**

Créer `test/harness/resolve-markers.py` :

```python
#!/usr/bin/env python3
"""Substitue les marqueurs d'un fichier d'ordres depuis un dump d'etat.

Usage: resolve-markers.py <dump.txt> <ordres.sql>
Ecrit le resultat sur la sortie standard.
Un marqueur non resolu fait sortir en code 1, jamais en avertissement.
"""
import re
import sys

MARQUEUR = re.compile(r"@([A-Z]+)\(([^)]*)\)@")


def charger(chemin):
    valeurs = {}
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            if " = " not in ligne:
                continue
            cle, valeur = ligne.rstrip("\n").split(" = ", 1)
            valeurs[cle] = valeur
    return valeurs


def numero_par_nom(valeurs, nom):
    # La cle doit etre exactement "commandant.<n>.nom" : une flotte porte elle
    # aussi une cle qui commence par "commandant." et finit par ".nom", et une
    # flotte homonyme d'un commandant repondrait a sa place.
    for cle, valeur in valeurs.items():
        parts = cle.split(".")
        if len(parts) == 3 and parts[0] == "commandant" and parts[2] == "nom" and valeur == nom:
            return parts[1]
    raise KeyError("aucun commandant nomme %r dans le dump" % nom)


def rangs(valeurs, prefixe, suffixe):
    """Numeros tries des cles de la forme <prefixe>.<n>.<suffixe>."""
    trouves = set()
    for cle in valeurs:
        if cle.startswith(prefixe + ".") and cle.endswith("." + suffixe):
            reste = cle[len(prefixe) + 1:-len(suffixe) - 1]
            if reste.isdigit():
                trouves.add(int(reste))
    return sorted(trouves)


def resoudre(valeurs, genre, args):
    parts = [a.strip() for a in args.split(",")]
    nom = parts[0]
    num = numero_par_nom(valeurs, nom)
    if genre == "NUM":
        return num
    if genre in ("CAP", "CAPG", "CAPY", "CAPX"):
        capitale = valeurs["commandant.%s.capitale" % num]
        if capitale == "-":
            raise KeyError("le commandant %r n'a pas de capitale" % nom)
        if genre == "CAP":
            return capitale
        g, y, x = capitale.split("_")
        return {"CAPG": g, "CAPY": y, "CAPX": x}[genre]
    if genre == "FLOTTE":
        rang = int(parts[1])
        numeros = rangs(valeurs, "commandant.%s.flotte" % num, "position")
        if rang >= len(numeros):
            raise KeyError("le commandant %r n'a que %d flotte(s)" % (nom, len(numeros)))
        return str(numeros[rang])
    if genre == "OFFRE":
        ids = sorted(
            int(cle.split(".")[1])
            for cle, valeur in valeurs.items()
            if cle.startswith("offre.") and cle.endswith(".vendeur") and valeur == num
        )
        rang = int(parts[1])
        if rang >= len(ids):
            raise KeyError("le commandant %r n'a que %d offre(s)" % (nom, len(ids)))
        return str(ids[rang])
    raise KeyError("marqueur inconnu: %s" % genre)


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    valeurs = charger(sys.argv[1])
    with open(sys.argv[2], encoding="utf-8") as f:
        texte = f.read()

    erreurs = []

    def remplacer(m):
        try:
            return resoudre(valeurs, m.group(1), m.group(2))
        except KeyError as e:
            erreurs.append("%s: %s" % (m.group(0), e))
            return m.group(0)

    resultat = MARQUEUR.sub(remplacer, texte)
    if erreurs:
        for e in erreurs:
            print("marqueur non resolu, " + e, file=sys.stderr)
        return 1
    if "@" in resultat and MARQUEUR.search(resultat):
        print("marqueur residuel apres substitution", file=sys.stderr)
        return 1
    sys.stdout.write(resultat)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x test/harness/resolve-markers.py
```

- [ ] **Step 3: Écrire le lanceur de scénario**

Créer `test/harness/run-scenario.sh` :

```bash
#!/usr/bin/env bash
# Déroule un scénario de bout en bout et le confronte à ses références.
#
# Usage: run-scenario.sh <scenario> [--update-golden] [--workdir DIR]
#
# Le script ignore entièrement le contenu du scénario. Ajouter un scénario est
# un dossier sous test/scenarios/, jamais une ligne ici.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENARIO="${1:?usage: run-scenario.sh <scenario> [--update-golden] [--workdir DIR]}"
shift
UPDATE=0
WORK="$REPO/test/work/$SCENARIO"

while [ $# -gt 0 ]; do
  case "$1" in
    --update-golden) UPDATE=1 ;;
    --workdir) WORK="$2"; shift ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
  esac
  shift
done

DIR="$REPO/test/scenarios/$SCENARIO"
test -d "$DIR" || { echo "scénario inconnu: $SCENARIO" >&2; exit 2; }

SEED="$(propriete "$DIR/scenario.properties" RANDOM_SEED)"
DATE_FIGEE="$(propriete "$DIR/scenario.properties" DATE_FIGEE)"
TOURS="$(propriete "$DIR/scenario.properties" TOURS)"

echo "== $SCENARIO : graine $SEED, $TOURS tour(s), répertoire $WORK"

preparer_workdir "$WORK" "$SEED" "$DATE_FIGEE"
reinitialiser_base

echo "-- init"
moteur "$WORK" init > "$WORK/init.log" 2>&1

echo "-- setup.sql"
injecter_sql "$DIR/setup.sql"

echo "-- newRound d'inscription"
moteur "$WORK" newRound > "$WORK/round-0.log" 2>&1
moteur "$WORK" dumpState "$WORK/dump-tour-0.txt"

ECHECS=0

for n in $(seq 1 "$TOURS"); do
  ordres="$DIR/turn-$n.sql"
  if [ -f "$ordres" ]; then
    echo "-- tour $n : substitution des marqueurs"
    if ! python3 "$REPO/test/harness/resolve-markers.py" \
         "$WORK/dump-tour-$((n-1)).txt" "$ordres" > "$WORK/turn-$n.resolved.sql"; then
      echo "ECHEC: marqueurs non résolus dans $ordres" >&2
      exit 1
    fi
    injecter_sql "$WORK/turn-$n.resolved.sql"
  else
    echo "-- tour $n : aucun ordre"
  fi

  echo "-- tour $n : newRound"
  moteur "$WORK" newRound > "$WORK/round-$n.log" 2>&1
  moteur "$WORK" dumpState "$WORK/dump-tour-$n.txt"

  golden="$DIR/golden/dump-tour-$n.txt"
  if [ "$UPDATE" = "1" ]; then
    mkdir -p "$DIR/golden"
    cp "$WORK/dump-tour-$n.txt" "$golden"
    echo "-- tour $n : golden régénéré"
    continue
  fi

  if [ ! -f "$golden" ]; then
    echo "ECHEC: golden absent: $golden" >&2
    ECHECS=$((ECHECS+1))
    continue
  fi

  if /usr/bin/diff -u "$golden" "$WORK/dump-tour-$n.txt" > "$WORK/diff-tour-$n.txt"; then
    echo "-- tour $n : conforme au golden"
  else
    echo "ECHEC: tour $n diverge du golden ($(grep -c '^[+-]' "$WORK/diff-tour-$n.txt") lignes)" >&2
    head -40 "$WORK/diff-tour-$n.txt" >&2
    ECHECS=$((ECHECS+1))
  fi
done

if [ "$UPDATE" = "1" ]; then
  echo "== goldens régénérés pour $SCENARIO, relire le diff avant de committer"
  exit 0
fi

echo "-- assertions"
DERNIER="$WORK/dump-tour-$TOURS.txt"
while IFS= read -r ligne; do
  case "$ligne" in ''|\#*) continue ;; esac
  if ! grep -qxF "$ligne" "$DERNIER"; then
    echo "ECHEC assertion: $ligne" >&2
    ECHECS=$((ECHECS+1))
  fi
done < "$DIR/assertions.txt"

echo "-- structure des rapports XML"
dernier_tour_dir="$WORK/data/tour$TOURS/rapports"
if [ -d "$dernier_tour_dir" ]; then
  for xml in $(find "$dernier_tour_dir" -name '*.xml'); do
    test -s "$xml" || { echo "ECHEC: rapport XML vide: $xml" >&2; ECHECS=$((ECHECS+1)); }
    python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$xml" \
      || { echo "ECHEC: rapport XML mal formé: $xml" >&2; ECHECS=$((ECHECS+1)); }
  done
fi

if [ "$ECHECS" -gt 0 ]; then
  echo "== $SCENARIO : $ECHECS échec(s)" >&2
  exit 1
fi
echo "== $SCENARIO : OK"
```

```bash
chmod +x test/harness/run-scenario.sh
```

- [ ] **Step 4: Écrire les deux scripts satellites**

Créer `test/harness/update-golden.sh` :

```bash
#!/usr/bin/env bash
# Seule voie de régénération des références. Son diff part en revue.
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/run-scenario.sh" "${1:?usage: update-golden.sh <scenario>}" --update-golden
```

Créer `test/harness/check-determinisme.sh` :

```bash
#!/usr/bin/env bash
# Rejoue deux fois le même scénario et compare les deux dumps entre eux.
# Ne consulte jamais le golden : ce contrôle atteste du déterminisme du moteur,
# pas de la conformité à une référence.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
SCENARIO="${1:?usage: check-determinisme.sh <scenario>}"
TOURS="$(propriete "$REPO/test/scenarios/$SCENARIO/scenario.properties" TOURS)"

# Le golden versionne est restaure apres chaque passe. Quand le scenario n'en a
# pas encore (premier contact, avant d'avoir figé quoi que ce soit), git checkout
# echoue sur un chemin non suivi : on supprime alors le repertoire produit.
restaurer_golden() {
  git -C "$REPO" checkout -- "test/scenarios/$SCENARIO/golden" 2>/dev/null \
    || rm -rf "$REPO/test/scenarios/$SCENARIO/golden"
}

capturer() {
  local cible="$1" workdir="$2"
  rm -rf "$cible"
  "$REPO/test/harness/run-scenario.sh" "$SCENARIO" --update-golden --workdir "$workdir" > /dev/null
  cp -R "$REPO/test/scenarios/$SCENARIO/golden" "$cible"
  restaurer_golden
}

trap restaurer_golden EXIT

capturer "$REPO/test/work/golden-a" "$REPO/test/work/det-a"
capturer "$REPO/test/work/golden-b" "$REPO/test/work/det-b"

ECHECS=0
for n in $(seq 1 "$TOURS"); do
  if ! /usr/bin/diff -u "$REPO/test/work/golden-a/dump-tour-$n.txt" \
                        "$REPO/test/work/golden-b/dump-tour-$n.txt" > "$REPO/test/work/det-diff-$n.txt"; then
    echo "ECHEC: le tour $n n'est pas reproductible" >&2
    head -40 "$REPO/test/work/det-diff-$n.txt" >&2
    ECHECS=$((ECHECS+1))
  fi
done

test "$ECHECS" = "0" || exit 1
echo "OK: $SCENARIO est reproductible sur $TOURS tour(s)"
```

```bash
chmod +x test/harness/update-golden.sh test/harness/check-determinisme.sh
```

Le passage par `--update-golden` puis `git checkout` évite de dupliquer la logique de déroulement. Le golden versionné est restauré dans tous les cas ; si le script est interrompu, un `git checkout -- test/scenarios/` le remet en état.

- [ ] **Step 5: Écrire le scénario `01-combat`**

Créer `test/scenarios/01-combat/scenario.properties` :

```properties
# Deux commandants, une flotte envoyée sur l'autre, un combat au tour 2.
# Sous surveillance : Combat.resolutionCombats, StrategieDeCombatSpatial,
# l'attribution des dégâts à l'attaquant corrigée en a3683e4.
RANDOM_SEED = 20260818
DATE_FIGEE = 01/01/2000
TOURS = 2
```

Créer `test/scenarios/01-combat/setup.sql` :

```sql
-- Deux commandants de races différentes, dix chasseurs standard chacun.
-- L'ADRESSE sert de clé de jointure entre aa_inscription et aa_vaisseaux,
-- et doit passer InternetAddress.parse (ProductionOrdres.java:461).
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Alpha', 'alpha@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Beta',  'beta@sheril.test',  1, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('alpha@sheril.test', 3, 10);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('beta@sheril.test',  3, 10);
```

Créer `test/scenarios/01-combat/turn-1.sql` :

```sql
-- Alpha se donne une stratégie agressive et lance sa flotte 0 sur la
-- capitale de Beta, en directive d'attaque de toutes les flottes.
-- Les valeurs de DIRECTIVE et d'AGRESSIVITE viennent de Const.java:422-431
-- et Const.java:583-588.
DELETE FROM aa_inscription;
DELETE FROM aa_vaisseaux;

INSERT INTO creer_strategie (NUMERO, NOM, AGRESSIVITE, CIBLE)
VALUES (@NUM(Alpha)@, 'Assaut', 4, 0);

INSERT INTO deplacer_flotte (NUMERO, NUMFLOTTE, POSX, POSY, GALAXIE, DIRECTIVE, STRATEGIE)
VALUES (@NUM(Alpha)@, @FLOTTE(Alpha,0)@, @CAPX(Beta)@, @CAPY(Beta)@, @CAPG(Beta)@, 3, 'Assaut');
```

Créer `test/scenarios/01-combat/turn-2.sql` :

```sql
-- Aucun ordre neuf : on laisse la flotte d'Alpha arriver et le combat se
-- résoudre. Les tables d'ordres du tour précédent sont vidées par
-- ProductionOrdres.viderAnciensOrdres, rien à nettoyer ici.
```

Créer `test/scenarios/01-combat/assertions.txt` :

```
# Le golden détecte le changement, ces assertions garantissent qu'il reste
# quelque chose à détecter. Chaque ligne non vide et non commentée doit
# apparaître telle quelle dans le dump du dernier tour.
tour = 2
commandant.1.nom = Alpha
commandant.2.nom = Beta
commandant.1.humain = true
commandant.2.humain = true
```

Les numéros `1` et `2` sont ceux attribués par `Joueur.creerCommandant` après le neutre. Les vérifier au step 7 et corriger si le moteur en attribue d'autres.

- [ ] **Step 6: Lancer le harnais et vérifier qu'il échoue faute de golden**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
docker compose up -d db
./scripts/create-jar.sh
./test/harness/run-scenario.sh 01-combat
```

Attendu : ÉCHEC sur `golden absent: .../golden/dump-tour-1.txt`, après que les deux tours se soient déroulés sans erreur. Si la substitution de marqueurs échoue avant cela, corriger le SQL ou le résolveur avant de continuer : c'est le point le plus fragile du harnais.

- [ ] **Step 7: Vérifier que le scénario fait bien quelque chose**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
grep -E '^commandant\.[12]\.(nom|capitale|flottes) = ' test/work/01-combat/dump-tour-2.txt
diff <(grep '^commandant.1' test/work/01-combat/dump-tour-1.txt) \
     <(grep '^commandant.1' test/work/01-combat/dump-tour-2.txt) | head -20
grep -c 'combat' test/work/01-combat/round-2.log
```

Attendu : deux commandants humains numérotés `1` et `2`, chacun avec une capitale, et un diff non vide entre les tours 1 et 2 pour Alpha. Si les deux tours sont identiques, le scénario est vide et le golden ne vaudrait rien : reprendre les ordres du tour 1 avant de figer quoi que ce soit. Ajuster `assertions.txt` si les numéros diffèrent.

- [ ] **Step 8: Contrôler le déterminisme avant de figer le golden**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-determinisme.sh 01-combat
```

Attendu : `OK: 01-combat est reproductible sur 2 tour(s)`. Tant que ce contrôle est rouge, le golden ne veut rien dire : ne pas passer au step suivant.

- [ ] **Step 9: Figer le golden**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/update-golden.sh 01-combat
wc -l test/scenarios/01-combat/golden/*.txt
./test/harness/run-scenario.sh 01-combat
```

Attendu : les deux goldens créés, puis `== 01-combat : OK`.

- [ ] **Step 10: Ignorer le répertoire de travail**

Ajouter à `.gitignore` :

```
test/work/
```

- [ ] **Step 11: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add test/harness test/scenarios/01-combat .gitignore
git commit -m "feat(test): harnais de non-régression et scénario 01-combat (SHRL-46)"
```

---

### Task 7: Scénario `02-colonisation`

**Files:**
- Create: `test/scenarios/02-colonisation/scenario.properties`, `setup.sql`, `turn-1.sql`, `turn-2.sql`, `turn-3.sql`, `assertions.txt`, `golden/dump-tour-1.txt`, `golden/dump-tour-2.txt`, `golden/dump-tour-3.txt`

**Interfaces:**
- Consumes: `run-scenario.sh`, `update-golden.sh`, `check-determinisme.sh` et la convention de marqueurs de la tâche 6.
- Produces: le scénario que consomment le job `rapports` et le job `captures` de la tâche 10 et de la tâche 11, parce qu'il est le seul à produire trois tours de rapports pour deux commandants.

Sous surveillance : `Possession`, `Population`, `Planete`, la taxation.

- [ ] **Step 1: Écrire le scénario**

Créer `test/scenarios/02-colonisation/scenario.properties` :

```properties
# Un commandant colonise une planète voisine puis en modifie la taxation.
# Sous surveillance : Possession, Population, Planete, la taxation.
RANDOM_SEED = 20260819
DATE_FIGEE = 01/01/2000
TOURS = 3
```

Créer `test/scenarios/02-colonisation/setup.sql` :

```sql
-- Un colonisateur (plan numéro 9 de PLAN_DEPART, Univers.java) et quelques
-- chasseurs pour l'escorte. Deux commandants, le second sert de témoin
-- immobile et de second destinataire de rapport.
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Colon', 'colon@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Temoin', 'temoin@sheril.test', 2, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('colon@sheril.test', 9, 2);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('colon@sheril.test', 3, 3);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('temoin@sheril.test', 3, 5);
```

Créer `test/scenarios/02-colonisation/turn-1.sql` :

```sql
-- Le colonisateur utilise sa capacité sur la planète 0 de sa propre capitale.
-- utiliser_colonisateur prend (NUMERO, FLOTTE, PLANETE), cf. divers/base_sheril.sql.
DELETE FROM aa_inscription;
DELETE FROM aa_vaisseaux;

INSERT INTO utiliser_colonisateur (NUMERO, FLOTTE, PLANETE)
VALUES (@NUM(Colon)@, @FLOTTE(Colon,0)@, 0);
```

Créer `test/scenarios/02-colonisation/turn-2.sql` :

```sql
-- Taxation maximale sur la planète colonisée, pour faire bouger stabilité
-- et population au tour suivant. TAXATION_MAXIMALE vaut 5 (Const.java:176).
INSERT INTO modifier_taxation_planete (NUMERO, SYSTEME, TAXE, PLANETE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 5, 0);
```

Créer `test/scenarios/02-colonisation/turn-3.sql` :

```sql
-- Retour à une taxation nulle : le dump du tour 3 doit montrer l'effet des
-- deux réglages successifs sur la stabilité.
INSERT INTO modifier_taxation_planete (NUMERO, SYSTEME, TAXE, PLANETE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 0, 0);
```

Créer `test/scenarios/02-colonisation/assertions.txt` :

```
# Le commandant colonisateur doit posséder au moins une planète habitée à la
# fin, et le témoin doit toujours exister.
tour = 3
commandant.1.nom = Colon
commandant.2.nom = Temoin
commandant.1.humain = true
```

- [ ] **Step 2: Dérouler le scénario sans golden et vérifier ce qu'il produit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/run-scenario.sh 02-colonisation || true
grep -E '^commandant\.1\.(possessions|flottes) = ' test/work/02-colonisation/dump-tour-*.txt
grep -E '^systeme\..*\.planete\.0\.(proprio|taxation|stabilite) = ' test/work/02-colonisation/dump-tour-3.txt | head
```

Attendu : l'échec sur golden absent, mais un dump qui montre la colonisation. Si aucune planète ne change de propriétaire entre les tours 0 et 1, l'ordre `utiliser_colonisateur` n'a pas pris : vérifier dans `test/work/02-colonisation/round-1.log` que la ligne `utiliser_colonisateur(27) -` est bien passée, et ajuster le numéro de planète ou le plan de vaisseau.

- [ ] **Step 3: Contrôler le déterminisme**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-determinisme.sh 02-colonisation
```

Attendu : `OK: 02-colonisation est reproductible sur 3 tour(s)`.

- [ ] **Step 4: Vérifier que les rapports XML sont produits**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
find test/work/02-colonisation/data/tour3/rapports -name '*.xml' | wc -l
```

Attendu : au moins deux fichiers, un par commandant humain (`RapportXML.java:606`, écrits sous `Chemin.RAPPORTS`, soit `data/tour<N>/rapports/<num>/`).

- [ ] **Step 5: Figer le golden et vérifier**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/update-golden.sh 02-colonisation
./test/harness/run-scenario.sh 02-colonisation
```

Attendu : `== 02-colonisation : OK`.

- [ ] **Step 6: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add test/scenarios/02-colonisation
git commit -m "test(harnais): scénario 02-colonisation (SHRL-46)"
```

---

### Task 8: Scénario `03-marche`, et correction du règlement des enchères

Ce scénario est construit pour exhiber le défaut décrit en §3.3 de la spec. Il est donc écrit **avant** la correction, et son instabilité constatée avant d'être corrigée. Si le scénario est stable d'emblée, l'analyse est fausse quelque part et il faut le savoir avant de bâtir dessus.

**Files:**
- Create: `test/scenarios/03-marche/scenario.properties`, `setup.sql`, `turn-1.sql`, `turn-2.sql`, `turn-3.sql`, `assertions.txt`, `golden/dump-tour-*.txt`
- Modify: `sources/zIgzAg/jeu/oceane/ReceptionOrdres.java:253-260`

**Interfaces:**
- Consumes: le harnais de la tâche 6, les marqueurs `@OFFRE(...)@` et `@CAP(...)@`.
- Produces: `ReceptionOrdres.reglerEncheresMarche()` règle les offres dans l'ordre croissant de `OffreMarche.getId()`.

- [ ] **Step 1: Écrire le scénario**

Créer `test/scenarios/03-marche/scenario.properties` :

```properties
# Deux vendeurs, un acheteur qui enchérit sur les deux offres sans avoir les
# centaures des deux. Avant correction, l'ordre de parcours décide laquelle il
# remporte, et le scénario est instable d'une exécution à l'autre.
RANDOM_SEED = 20260820
DATE_FIGEE = 01/01/2000
TOURS = 3
```

Créer `test/scenarios/03-marche/setup.sql` :

```sql
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Vendeur1', 'v1@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Vendeur2', 'v2@sheril.test', 1, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Acheteur', 'a1@sheril.test', 2, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('v1@sheril.test', 3, 2);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('v2@sheril.test', 3, 2);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('a1@sheril.test', 3, 2);
```

Créer `test/scenarios/03-marche/turn-1.sql` :

```sql
-- Chaque vendeur met en vente depuis sa capitale. vendre_galactique prend
-- (NUMERO, v0 position, v1 code marchandise, v2 quantité, v3 prix unitaire),
-- cf. divers/base_sheril.sql:1095.
DELETE FROM aa_inscription;
DELETE FROM aa_vaisseaux;

INSERT INTO vendre_galactique (NUMERO, v0, v1, v2, v3)
VALUES (@NUM(Vendeur1)@, '@CAP(Vendeur1)@', '0', 50, 10);

INSERT INTO vendre_galactique (NUMERO, v0, v1, v2, v3)
VALUES (@NUM(Vendeur2)@, '@CAP(Vendeur2)@', '0', 50, 10);
```

Créer `test/scenarios/03-marche/turn-2.sql` :

```sql
-- L'acheteur enchérit sur les deux offres, chacune à un montant tel que la
-- somme des deux dépasse ses centaures. Une seule des deux peut aboutir, et
-- c'est l'ordre de parcours qui décide laquelle. C'est exactement le défaut
-- que ce scénario doit exhiber.
-- acheter_galactique prend (NUMERO, v0 id offre, v1 montant, v2 destination),
-- cf. divers/base_sheril.sql:1103.
INSERT INTO acheter_galactique (NUMERO, v0, v1, v2)
VALUES (@NUM(Acheteur)@, @OFFRE(Vendeur1,0)@, 600, '@CAP(Acheteur)@');

INSERT INTO acheter_galactique (NUMERO, v0, v1, v2)
VALUES (@NUM(Acheteur)@, @OFFRE(Vendeur2,0)@, 600, '@CAP(Acheteur)@');
```

Créer `test/scenarios/03-marche/turn-3.sql` :

```sql
-- Aucun ordre : on observe l'état après règlement, y compris la fin de vie
-- des offres non honorées (OffreMarche.gererFinDeVieEncheres).
```

Créer `test/scenarios/03-marche/assertions.txt` :

```
tour = 3
commandant.1.nom = Vendeur1
commandant.2.nom = Vendeur2
commandant.3.nom = Acheteur
```

- [ ] **Step 2: Vérifier que le scénario produit bien deux offres et deux enchères**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/run-scenario.sh 03-marche || true
grep '^offre\.' test/work/03-marche/dump-tour-1.txt
grep -E '^commandant\.3\.centaures = ' test/work/03-marche/dump-tour-*.txt
```

Attendu : deux offres au tour 1, avec deux vendeurs distincts. Si une seule offre apparaît, le montant ou la marchandise ne conviennent pas et il faut ajuster avant tout le reste.

Vérifier aussi que le montant de 600 est bien au-dessus de la moitié des centaures de l'acheteur au tour 1, sinon les deux enchères passent et le défaut ne se manifeste pas :

```bash
grep '^commandant.3.centaures' test/work/03-marche/dump-tour-1.txt
```

Ajuster les deux `600` de `turn-2.sql` pour que leur somme dépasse ce montant tout en restant chacun en dessous.

- [ ] **Step 3: Constater l'instabilité, c'est le test qui échoue**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-determinisme.sh 03-marche
```

Attendu : ÉCHEC, avec un diff portant sur `commandant.3.centaures`, sur les possessions de l'acheteur, et sur l'offre survivante. C'est la manifestation du hachage par identité de `OffreMarche` (`OffreMarche.java:5`, ni `equals` ni `hashCode`), utilisé comme clé de `encheresMarche` (`ReceptionOrdres.java:50`) et parcouru par `entrySet()` (`ReceptionOrdres.java:260`).

Si le contrôle passe, relancer cinq fois. S'il passe cinq fois, ne pas corriger : l'analyse de la spec est fausse quelque part, le noter dans le journal du ticket et demander un arbitrage avant de continuer.

- [ ] **Step 4: Trier les offres avant règlement**

Dans `sources/zIgzAg/jeu/oceane/ReceptionOrdres.java`, remplacer l'en-tête de `reglerEncheresMarche()` :

```java
	public void reglerEncheresMarche(){
		// on tri les enchères par montant décroissant
		encheresMarche.values().forEach(liste ->
				liste.sort(Comparator.comparingDouble(Enchere::montant).reversed())
		);

		// maintenant on regarde pour chaque offre
		for (Map.Entry<OffreMarche, List<Enchere>> entry : encheresMarche.entrySet()) {
```

par :

```java
	public void reglerEncheresMarche(){
		// on tri les enchères par montant décroissant
		encheresMarche.values().forEach(liste ->
				liste.sort(Comparator.comparingDouble(Enchere::montant).reversed())
		);

		// OffreMarche n'override pas hashCode : la clé est hachée par identité
		// mémoire et l'ordre de entrySet() change d'une exécution de JVM à
		// l'autre. Chaque offre réglée débitant les centaures de l'acheteur,
		// un commandant qui enchérit sur deux offres sans avoir les moyens des
		// deux remportait l'une ou l'autre selon l'ordre. On règle donc les
		// offres dans l'ordre croissant de leur identifiant, qui est stable.
		List<Map.Entry<OffreMarche, List<Enchere>>> offresTriees =
				new ArrayList<>(encheresMarche.entrySet());
		offresTriees.sort(Comparator.comparingInt(e -> e.getKey().getId()));

		// maintenant on regarde pour chaque offre
		for (Map.Entry<OffreMarche, List<Enchere>> entry : offresTriees) {
```

Vérifier que `java.util.ArrayList` et `java.util.List` sont importés :

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
grep -n "^import java.util" sources/zIgzAg/jeu/oceane/ReceptionOrdres.java
```

- [ ] **Step 5: Vérifier que le scénario est devenu stable**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./scripts/create-jar.sh && ./test/harness/check-determinisme.sh 03-marche
```

Attendu : `OK: 03-marche est reproductible sur 3 tour(s)`. Le relancer trois fois.

- [ ] **Step 6: Vérifier que les quatre autres contrôles tiennent toujours**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-init-determinisme.sh
./test/harness/check-composants-determinisme.sh
./test/harness/run-scenario.sh 01-combat
./test/harness/run-scenario.sh 02-colonisation
```

Attendu : les quatre passent. Le tri des enchères ne touche que le marché, aucun golden existant ne doit bouger. S'ils bougent, comprendre pourquoi avant de régénérer quoi que ce soit.

- [ ] **Step 7: Figer le golden**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/update-golden.sh 03-marche
./test/harness/run-scenario.sh 03-marche
```

Attendu : `== 03-marche : OK`.

- [ ] **Step 8: Commit**

Deux commits, parce que la correction du moteur vaut indépendamment du harnais et doit rester lisible seule.

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add sources/zIgzAg/jeu/oceane/ReceptionOrdres.java
git commit -m "fix(marche): régler les enchères dans l'ordre des identifiants d'offre (SHRL-46)"
git add test/scenarios/03-marche
git commit -m "test(harnais): scénario 03-marche (SHRL-46)"
```

---

### Task 9: Scénarios `04-recherche` et `05-alliances`

**Files:**
- Create: `test/scenarios/04-recherche/scenario.properties`, `setup.sql`, `turn-1.sql`, `assertions.txt`, `golden/`
- Create: `test/scenarios/05-alliances/scenario.properties`, `setup.sql`, `turn-1.sql` à `turn-4.sql`, `assertions.txt`, `golden/`

**Interfaces:**
- Consumes: le harnais de la tâche 6.
- Produces: les cinq entrées de la matrice du job `scenarios` de la tâche 10.

`04-recherche` est le seul scénario dont la durée n'est pas fixée par la spec. Elle se calibre ici.

- [ ] **Step 1: Écrire `04-recherche` avec une durée provisoire**

Créer `test/scenarios/04-recherche/scenario.properties` :

```properties
# Un commandant affecte tout son budget à une technologie et la cherche
# jusqu'à ce qu'elle aboutisse puis bascule au domaine public.
# Sous surveillance : Univers.gestionTechno, Technologie.testDevenirTechnologiesPubliques.
# TOURS est calibré au step 2, la valeur ci-dessous est provisoire.
RANDOM_SEED = 20260821
DATE_FIGEE = 01/01/2000
TOURS = 4
```

Créer `test/scenarios/04-recherche/setup.sql` :

```sql
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Savant', 'savant@sheril.test', 3, 0);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('savant@sheril.test', 3, 5);
```

Créer `test/scenarios/04-recherche/turn-1.sql` :

```sql
-- Tout le budget du système capitale sur la recherche, et 100 % de la
-- recherche sur une technologie. DOMAINES_BUDGET_TECHNOLOGIQUE vaut 0
-- (Const.java:164). Le code de technologie est un code de départ connu du
-- moteur, cf. ListeTechnologique.
DELETE FROM aa_inscription;
DELETE FROM aa_vaisseaux;

INSERT INTO modifier_budget (NUMERO, SYSTEME, BUDGET, POURCENTAGE)
VALUES (@NUM(Savant)@, '@CAP(Savant)@', 0, 100);

INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Savant)@, 'moteurII', 100);
```

Créer `test/scenarios/04-recherche/assertions.txt` :

```
tour = 4
commandant.1.nom = Savant
commandant.1.humain = true
```

- [ ] **Step 2: Calibrer la durée**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/run-scenario.sh 04-recherche || true
grep -E '^commandant\.1\.(technologies|recherche\.)' test/work/04-recherche/dump-tour-*.txt
```

Attendu : voir la progression des points de recherche, tour par tour, et le moment où `moteurII` passe de la ligne `.recherche.moteurII` à la liste `.technologies`. Fixer `TOURS` au premier tour où la technologie est acquise, plus un.

Si le compte de tours dépasse six, appliquer le repli prévu par la spec : augmenter le budget de recherche du commandant plutôt qu'allonger le scénario. Si `moteurII` n'existe pas, remplacer par un code présent dans `sources/zIgzAg/jeu/oceane/ListeTechnologique.java`, vérifié par :

```bash
grep -c 'moteurII' sources/zIgzAg/jeu/oceane/ListeTechnologique.java
```

- [ ] **Step 3: Contrôler le déterminisme et figer le golden de `04-recherche`**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-determinisme.sh 04-recherche
./test/harness/update-golden.sh 04-recherche
./test/harness/run-scenario.sh 04-recherche
```

Attendu : `OK`, puis `== 04-recherche : OK`.

- [ ] **Step 4: Écrire `05-alliances`**

Créer `test/scenarios/05-alliances/scenario.properties` :

```properties
# Création d'alliance, adhésion validée, élection d'un dirigeant, exclusion.
# Sous surveillance : Alliance.gererAlliances1/2, Alliance.traiterVotes.
RANDOM_SEED = 20260822
DATE_FIGEE = 01/01/2000
TOURS = 4
```

Créer `test/scenarios/05-alliances/setup.sql` :

```sql
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Chef',    'chef@sheril.test',    0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Membre',  'membre@sheril.test',  1, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Banni',   'banni@sheril.test',   2, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('chef@sheril.test',   3, 3);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('membre@sheril.test', 3, 3);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('banni@sheril.test',  3, 3);
```

Créer `test/scenarios/05-alliances/turn-1.sql` :

```sql
-- creer_alliance prend (NUMERO, ALLIANCE nom, SECRET, TYPE, DROITS).
-- SECRET = 1 signifie non secrète : ReceptionOrdres.creer_alliance passe
-- (tInt(o[1]) == 0) au paramètre "secrete". TYPE 0 = démocratique
-- (Const.ALLIANCE_TYPE_DEMOCRATIQUE, Const.java:219).
DELETE FROM aa_inscription;
DELETE FROM aa_vaisseaux;

INSERT INTO creer_alliance (NUMERO, ALLIANCE, SECRET, TYPE, DROITS)
VALUES (@NUM(Chef)@, 'Pacte du Nord', 1, 0, 0);
```

Créer `test/scenarios/05-alliances/turn-2.sql` :

```sql
-- Les deux autres demandent à adhérer, le chef valide les deux.
-- L'adhésion n'aboutit que si l'ordre valider_adhesion_alliance du dirigeant
-- existe dans le même tour (ReceptionOrdres.adherer_alliance).
INSERT INTO adherer_alliance (NUMERO, ALLIANCE) VALUES (@NUM(Membre)@, 0);
INSERT INTO adherer_alliance (NUMERO, ALLIANCE) VALUES (@NUM(Banni)@, 0);

INSERT INTO valider_adhesion_alliance (NUMERO, POSTULANT, ALLIANCE)
VALUES (@NUM(Chef)@, @NUM(Membre)@, 0);
INSERT INTO valider_adhesion_alliance (NUMERO, POSTULANT, ALLIANCE)
VALUES (@NUM(Chef)@, @NUM(Banni)@, 0);
```

Créer `test/scenarios/05-alliances/turn-3.sql` :

```sql
-- Les trois membres votent pour élire Membre dirigeant.
INSERT INTO nommer_dirigeant (NUMERO, ALLIANCE, DIRIGEANT) VALUES (@NUM(Chef)@,   0, @NUM(Membre)@);
INSERT INTO nommer_dirigeant (NUMERO, ALLIANCE, DIRIGEANT) VALUES (@NUM(Membre)@, 0, @NUM(Membre)@);
INSERT INTO nommer_dirigeant (NUMERO, ALLIANCE, DIRIGEANT) VALUES (@NUM(Banni)@,  0, @NUM(Membre)@);
```

Créer `test/scenarios/05-alliances/turn-4.sql` :

```sql
-- Deux voix sur trois pour exclure Banni. VOTE = 1 pour l'exclusion.
INSERT INTO exclure_alliance (NUMERO, ALLIANCE, VOTE) VALUES (@NUM(Chef)@,   0, 1);
INSERT INTO exclure_alliance (NUMERO, ALLIANCE, VOTE) VALUES (@NUM(Membre)@, 0, 1);
```

Créer `test/scenarios/05-alliances/assertions.txt` :

```
tour = 4
alliance.0.nom = Pacte du Nord
commandant.1.nom = Chef
commandant.2.nom = Membre
commandant.3.nom = Banni
```

- [ ] **Step 5: Dérouler `05-alliances` et vérifier que chaque étape prend**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/run-scenario.sh 05-alliances || true
for n in 1 2 3 4; do echo "== tour $n"; grep '^alliance\.' test/work/05-alliances/dump-tour-$n.txt; done
```

Attendu, dans l'ordre des tours : l'alliance apparaît au tour 1 avec un seul membre, passe à trois membres au tour 2, change de dirigeant au tour 3, redescend à deux membres au tour 4. Toute étape qui n'apparaît pas est un ordre rejeté : lire le `round-<n>.log` correspondant avant d'ajuster. Corriger le numéro d'alliance dans les ordres si le moteur n'attribue pas `0` (`Univers.trouverNumeroLibreAlliance`, `Univers.java:522`), et l'ajuster aussi dans `assertions.txt`.

- [ ] **Step 6: Contrôler le déterminisme et figer le golden de `05-alliances`**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/check-determinisme.sh 05-alliances
./test/harness/update-golden.sh 05-alliances
./test/harness/run-scenario.sh 05-alliances
```

Attendu : `OK`, puis `== 05-alliances : OK`.

- [ ] **Step 7: Passer les cinq scénarios d'affilée**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
for s in 01-combat 02-colonisation 03-marche 04-recherche 05-alliances; do
  ./test/harness/run-scenario.sh "$s" || echo "ECHEC: $s"
done
```

Attendu : cinq `== <scenario> : OK`, aucun `ECHEC`.

- [ ] **Step 8: Commit**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add test/scenarios/04-recherche test/scenarios/05-alliances
git commit -m "test(harnais): scénarios 04-recherche et 05-alliances (SHRL-46)"
```

---

### Task 10: Le workflow GitHub

**Files:**
- Create: `.github/workflows/harness.yml`

**Interfaces:**
- Consumes: `run-scenario.sh` et `check-determinisme.sh`, avec `MYSQL_CLI` et `DB_HOST` surchargés pour viser le service MySQL du job.
- Produces: quatre jobs déclenchés sur `pull_request`, sur `push` vers `main`, et sur `workflow_dispatch`.

`.github/workflows/compile.yml` reste inchangé et continue de rendre la main en une trentaine de secondes. Le nouveau fichier ne le remplace pas, il s'y ajoute.

- [ ] **Step 1: Écrire le workflow**

Créer `.github/workflows/harness.yml` :

```yaml
name: Harnais de non-régression

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - name: Construire le jar
        run: ./scripts/create-jar.sh
      - uses: actions/upload-artifact@v4
        with:
          name: sheril-jar
          path: sheril.jar
          retention-days: 1

  scenarios:
    needs: build
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        scenario:
          - 01-combat
          - 02-colonisation
          - 03-marche
          - 04-recherche
          - 05-alliances
    services:
      db:
        image: mysql:5
        env:
          MYSQL_DATABASE: sheril
          MYSQL_USER: user
          MYSQL_PASSWORD: password
          MYSQL_ROOT_PASSWORD: password
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -ppassword" --health-interval=5s
          --health-timeout=5s --health-retries=20
    env:
      MYSQL_CLI: mysql -h 127.0.0.1 -P 3306
      DB_HOST: 127.0.0.1:3306
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - uses: actions/download-artifact@v4
        with:
          name: sheril-jar
      - name: Installer le client MySQL
        run: sudo apt-get update && sudo apt-get install -y mysql-client
      - name: Jouer le scénario
        run: ./test/harness/run-scenario.sh ${{ matrix.scenario }}
      - name: Publier le dump et le diff en cas d'échec
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: dump-${{ matrix.scenario }}
          path: |
            test/work/${{ matrix.scenario }}/dump-tour-*.txt
            test/work/${{ matrix.scenario }}/diff-tour-*.txt
            test/work/${{ matrix.scenario }}/round-*.log
          retention-days: 7

  determinisme:
    needs: build
    runs-on: ubuntu-latest
    services:
      db:
        image: mysql:5
        env:
          MYSQL_DATABASE: sheril
          MYSQL_USER: user
          MYSQL_PASSWORD: password
          MYSQL_ROOT_PASSWORD: password
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -ppassword" --health-interval=5s
          --health-timeout=5s --health-retries=20
    env:
      MYSQL_CLI: mysql -h 127.0.0.1 -P 3306
      DB_HOST: 127.0.0.1:3306
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - uses: actions/download-artifact@v4
        with:
          name: sheril-jar
      - name: Installer le client MySQL
        run: sudo apt-get update && sudo apt-get install -y mysql-client
      - name: Déterminisme de l'initialisation
        run: ./test/harness/check-init-determinisme.sh
      - name: Déterminisme d'un tour joué
        run: ./test/harness/check-determinisme.sh 01-combat
      - name: Publier les diffs en cas d'échec
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: determinisme-diffs
          path: test/work/*diff*.txt
          retention-days: 7

  rapports:
    needs: build
    runs-on: ubuntu-latest
    services:
      db:
        image: mysql:5
        env:
          MYSQL_DATABASE: sheril
          MYSQL_USER: user
          MYSQL_PASSWORD: password
          MYSQL_ROOT_PASSWORD: password
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -ppassword" --health-interval=5s
          --health-timeout=5s --health-retries=20
    env:
      MYSQL_CLI: mysql -h 127.0.0.1 -P 3306
      DB_HOST: 127.0.0.1:3306
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - uses: actions/download-artifact@v4
        with:
          name: sheril-jar
      - name: Installer le client MySQL
        run: sudo apt-get update && sudo apt-get install -y mysql-client
      - name: Jouer 02-colonisation
        run: ./test/harness/run-scenario.sh 02-colonisation
      - name: Vérifier qu'il y a un rapport XML par commandant humain
        run: |
          set -euo pipefail
          nb_xml=$(find test/work/02-colonisation/data/tour3/rapports -name '*.xml' | wc -l)
          echo "rapports XML: $nb_xml"
          test "$nb_xml" -ge 2
```

`run-scenario.sh` contrôle déjà que chaque XML est non vide et bien formé ; le job ajoute le décompte, qui est la seule chose que le script ne peut pas savoir sans connaître le scénario.

- [ ] **Step 2: Vérifier la syntaxe du workflow**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
python3 -c "import sys,yaml; yaml.safe_load(open('.github/workflows/harness.yml'))" && echo "YAML valide"
```

Attendu : `YAML valide`. Si `yaml` n'est pas disponible, `python3 -m pip install --user pyyaml` ou sauter ce contrôle, la validation réelle vient du push.

- [ ] **Step 3: Vérifier que les scripts marchent avec un client MySQL nu**

Le `MYSQL_CLI` de CI n'est pas `docker compose exec`. Contrôler en local que les scripts ne dépendent pas de la forme compose :

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
MYSQL_CLI="docker compose exec -T db mysql" DB_HOST="127.0.0.1:3311" ./test/harness/run-scenario.sh 01-combat
```

Attendu : `== 01-combat : OK`. Si le client `mysql` local est installé, refaire avec `MYSQL_CLI="mysql -h 127.0.0.1 -P 3311"` pour valider la forme utilisée en CI.

- [ ] **Step 4: Commit et pousser, puis lire le résultat du workflow**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git add .github/workflows/harness.yml
git commit -m "ci: workflow de non-régression du moteur (SHRL-46)"
git push origin HEAD
gh run watch
```

Attendu : les quatre jobs verts. Un job `scenarios` rouge doit publier son artefact `dump-<scenario>` : le télécharger et vérifier que le diff est lisible, c'est la raison d'être de cette étape. Un golden qui ne se diagnostique pas depuis l'artefact rend l'outil inutilisable, et c'est à corriger ici, pas plus tard.

---

### Task 11: Capture visuelle des rapports HTML

**Files:**
- Modify: `.github/workflows/harness.yml`, ajout du job `captures`

**Interfaces:**
- Consumes: `scripts/capture-rapports.py`, livré sur la branche `feat/capture-rapports` d'`origin`, commit `020b0c5`. Deux modes.
  - Capture : un seul argument, le chemin `data/tour<N>/rapports`. Sortie, un PNG et un PDF par page plus une galerie `index.html`. Code retour 0 si tout a rendu, 1 s'il reste des pages en échec.
  - Comparaison : `--diff <reference> --diff-seul`. Ne lit que le HTML, ne lance pas Chrome, écrit un `diff.html` navigable. Code retour 0 si identique, 1 s'il y a des différences, 2 en cas d'échec. Neutralise déjà la date au format `JJ/MM/AAAA` et accepte `--ignorer <regex>`.
- Produces: un job terminal et non bloquant, dont l'échec ne fait pas tomber le golden.

**Le mode `--diff` ne devient pas un golden HTML.** La spec exclut explicitement le HTML du périmètre de comparaison, parce que sa mise en forme change souvent et en ferait une référence bruyante. Le mode comparaison sert au diagnostic manuel, quand une capture surprend et qu'on veut savoir ce qui a bougé. Le `--ignorer <regex>` qui permettrait de neutraliser les champs aléatoires n'est pas utilisé ici : masquer un champ non déterministe traite le symptôme, alors que la tâche 3 traite la cause en semant le générateur. Une fois `RANDOM_SEED` posée, ces champs sont stables et n'ont plus à être masqués.

Le script est validé sur une fixture reconstruite à partir des vrais gabarits, jamais sur une sortie moteur réelle. Le premier tour produit par ce harnais est aussi son premier test grandeur nature. L'essai local du step 2 précède donc obligatoirement le câblage en CI.

- [ ] **Step 1: Intégrer la branche de capture**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
git fetch origin feat/capture-rapports
git merge --no-ff origin/feat/capture-rapports -m "merge: capture visuelle des rapports (SHRL-46)"
test -f scripts/capture-rapports.py && echo "script présent"
```

Attendu : `script présent`. En cas de conflit, il ne peut porter que sur des fichiers disjoints de ce chantier : le résoudre en gardant les deux apports.

- [ ] **Step 2: Essayer le script sur une sortie moteur réelle, en local**

Les deux sorties ne cohabitent pas au même endroit : le XML est sous `rapports/<num>/`, le HTML sous `rapports/<num>tour<N>/` (`Rapport.java:755`).

Ce point a été vérifié par la session `capture-rapports` sur un arbre mixte fabriqué pour l'occasion, plutôt que supposé. Le script liste les répertoires sur l'expression `^(\d+)tour(\d+)$` et ne capture que les `*.htm` : les répertoires de XML posés à côté sont ignorés sans bruit et sans faux écart, et le `rapport.xml` qui vit dans les répertoires HTML l'est aussi. Aucune précaution n'est donc à prendre sur ce point.

**Le vrai point de vigilance est ailleurs : `images/` doit rester le frère des `<num>tour<N>/`.** Le CSS et les images sont référencés en relatif depuis le répertoire du commandant (`Rapport.java:61`), et `Chemin.initialiserChemins` copie `data/fichiers/images` vers `Chemin.RAPPORTS_IMAGES`, soit `data/tour<N>/rapports/images/`. Un job qui archiverait ou déplacerait les rapports avant de les capturer produirait des pages nues, et l'échec serait silencieux : le script ne rend `KO` que sur un fichier vide. Le job ci-dessous capture en place, donc la contrainte est tenue. Si un jour il faut déplacer l'arbre, utiliser l'option `--archiver` du script, qui recopie `images/` à côté.

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
./test/harness/run-scenario.sh 02-colonisation
ls test/work/02-colonisation/data/tour3/rapports/
python3 scripts/capture-rapports.py test/work/02-colonisation/data/tour3/rapports
echo "code retour: $?"
find test/work/02-colonisation/data/tour3/rapports -name '*.png' | wc -l
```

Attendu : code retour 0, et au moins un PNG par commandant humain. Si le script sort en 1, lire son message : c'est le premier contact avec une sortie moteur réelle, et l'écart éventuel se corrige côté script de capture, pas côté harnais.

- [ ] **Step 3: Vérifier la présence d'un Chrome sur le runner**

La spec relève que la présence d'un Chrome sur `ubuntu-latest` n'est pas vérifiée. Le job la vérifie explicitement, et installe si besoin.

- [ ] **Step 4: Ajouter le job `captures`**

Ajouter à la fin de `.github/workflows/harness.yml` :

```yaml
  captures:
    needs: build
    runs-on: ubuntu-latest
    continue-on-error: true
    services:
      db:
        image: mysql:5
        env:
          MYSQL_DATABASE: sheril
          MYSQL_USER: user
          MYSQL_PASSWORD: password
          MYSQL_ROOT_PASSWORD: password
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -ppassword" --health-interval=5s
          --health-timeout=5s --health-retries=20
    env:
      MYSQL_CLI: mysql -h 127.0.0.1 -P 3306
      DB_HOST: 127.0.0.1:3306
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - uses: actions/download-artifact@v4
        with:
          name: sheril-jar
      - name: Installer le client MySQL
        run: sudo apt-get update && sudo apt-get install -y mysql-client
      - name: Vérifier la présence d'un Chrome
        run: |
          set -euo pipefail
          if command -v google-chrome || command -v chromium-browser || command -v chromium; then
            echo "Chrome déjà présent sur le runner"
          else
            echo "Aucun Chrome, installation de chromium-browser"
            sudo apt-get install -y chromium-browser
          fi
      - name: Jouer 02-colonisation
        run: ./test/harness/run-scenario.sh 02-colonisation
      - name: Capturer les rapports
        run: python3 scripts/capture-rapports.py test/work/02-colonisation/data/tour3/rapports
      - uses: actions/upload-artifact@v4
        with:
          name: captures-rapports
          path: |
            test/work/02-colonisation/data/tour3/rapports/**/*.png
            test/work/02-colonisation/data/tour3/rapports/**/*.pdf
            test/work/02-colonisation/data/tour3/rapports/**/index.html
          retention-days: 14
```

`continue-on-error: true` est le point non négociable de ce job : une capture qui échoue ne doit jamais faire tomber le golden. Le job `rapports` de la tâche 10 reste, lui, bloquant.

- [ ] **Step 5: Vérifier la syntaxe puis pousser**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
python3 -c "import sys,yaml; yaml.safe_load(open('.github/workflows/harness.yml'))" && echo "YAML valide"
git add .github/workflows/harness.yml
git commit -m "ci: job de capture visuelle des rapports, non bloquant (SHRL-46)"
git push origin HEAD
gh run watch
```

Attendu : `captures` produit son artefact. S'il échoue, le reste du workflow reste vert, ce qui est exactement le comportement voulu.

- [ ] **Step 6: Ouvrir la PR**

```bash
cd /Users/sbt/perso/pbem/sheril-contrib
gh pr create --base main --head "$(git branch --show-current)" \
  --title "Harnais de non-régression du moteur" --fill
```

La description suit la règle du repo : un paragraphe par fichier touché, ce que le diff fait, la source qui l'établit. Pas d'accroche contextuelle, pas de métriques sur le changement, pas de feuille de route, pas de question ouverte. Aucune PR vers `upstream`.

---

## Ce que le plan ne fait pas

- Il ne teste pas la console PHP. Le harnais injecte les ordres en base, il ne passe pas par les formulaires qui les produisent normalement.
- Il ne compare pas le HTML des rapports. Ce HTML porte une date (`Rapport.java:1297`) et sa mise en forme change souvent, ce qui en ferait un golden bruyant. Une capture se regarde, elle ne se diffe pas.
- Il ne corrige pas `AugmentationTaille.java`, code mort, pour la raison exposée en tête de document.
- Il ne rend pas `Const.NB_SECTEURS_X` ni `Const.NB_SYSTEMES_PAR_SECTEUR` configurables. C'est le levier de repli si la mesure de la tâche 1 dépasse 180 secondes par tour, et c'est alors un chantier à ouvrir séparément.
- Il ne traite pas les deux copies divergentes de `rapport.css` (`data/fichiers/images/rapport.css`, 10205 octets, et `php/images/rapport.css`, 9734 octets, contenus différents). Hors périmètre, à arbitrer à part.
