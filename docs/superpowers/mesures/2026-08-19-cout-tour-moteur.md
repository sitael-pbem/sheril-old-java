# Coût d'un tour de moteur (SHRL-46)

## Machine et JDK

Mac ARM (Darwin 24.6.0, macOS 15.7, arm64 T6041), `mysql:5` en émulation
amd64 sous Docker Desktop/Rancher, avec :

```
openjdk version "25.0.2" 2026-01-20
OpenJDK Runtime Environment Homebrew (build 25.0.2)
OpenJDK 64-Bit Server VM Homebrew (build 25.0.2, mixed mode, sharing)
```

Écart avec l'environnement de la session `capture-rapports` : cette session
a mesuré avec un JDK temurin 21. Sur cette machine, seul un `openjdk`
Homebrew (25.0.2) est installé, aucun temurin 21 n'a été trouvé (ni via
`java_home`, ni via `jenv`/`sdkman`). La compilation et l'exécution ont donc
été faites avec ce JDK, en ajoutant `/opt/homebrew/opt/openjdk/bin` en tête
de `PATH`. Écart également sur le schéma chargé : 130 tables (131 lignes
avec l'en-tête `SHOW TABLES`), contre les 125/126 indiquées dans l'« Attendu »
du step 4 du brief, ce qui correspond au chiffre déjà relevé par la session
`capture-rapports`.

## Mesures locales (2026-08-19)

| Poste | Durée |
|---|---|
| `docker compose up -d` jusqu'à MySQL joignable, 130 tables chargées | 5 s |
| `Start init` seul | 0,72 s |
| `Start newRound` à vide (aucun commandant) | 1,23 s |
| `Start newRound`, deux commandants (second appel, mesure de référence) | 1,26 s |

## Série de la session `capture-rapports` (2026-08-19, reproduite)

| Poste | Durée |
|---|---|
| `docker compose up -d` jusqu'à MySQL joignable, 130 tables chargées | 10 s |
| `Start init` seul | 1,03 s puis 0,95 s |
| `Start addNewGalaxy 0` | 1,28 s puis 1,22 s |
| `scripts/init.sh` complet | environ 2,3 s de moteur |
| `Start newRound`, trois commandants | 2 s |
| Plancher d'un appel, JVM plus `docker compose exec`, mesuré sur `Start help` | 0,15 s |

## Écart entre les deux séries

Les durées locales sont systématiquement plus courtes que celles de la
session `capture-rapports` : MySQL joignable en 5 s contre 10 s, `Start init`
en 0,72 s contre 0,95-1,03 s, et le tour joué (deux commandants ici, trois
dans l'autre série) en 1,26 s contre 2 s. L'écart va dans le même sens sur
tous les postes, ce qui est cohérent avec un JDK différent (25.0.2 contre
temurin 21) plutôt qu'avec une mesure incohérente. Les deux séries
s'accordent sur l'ordre de grandeur : moins de 1,5 s pour une initialisation,
autour de 1 à 2 s pour un tour joué.

## Extrapolation à cinq scénarios de trois à six tours

Dix-huit tours plus cinq `init`, en prenant le poste le plus coûteux mesuré
localement pour chaque catégorie (tour à deux commandants pour les dix-huit
tours, `Start init` pour les cinq initialisations) :

- 18 tours x 1,26 s = 22,68 s
- 5 `init` x 0,72 s = 3,6 s
- Total moteur : 26,28 s
- Plus la base MySQL, payée une fois par job (5 à 10 s selon la série) : 31,3 à 36,3 s

Avec la série `capture-rapports` (JDK temurin 21, chiffres plus hauts), le
même calcul donne 18 x 2 s + 5 x 1 s = 41 s de moteur, plus 10 s de MySQL,
soit 51 s.

## Décision

Le tour à deux joueurs est mesuré à 1,26 s localement (2 s dans la série
`capture-rapports` à trois joueurs), très en dessous du seuil de 60 secondes
de la règle de décision du step 8. Le harnais tient en CI tel qu'il est
spécifié : passage à la tâche 2, sans ouvrir le levier de repli de la spec
(rendre `Const.NB_SECTEURS_X` et `Const.NB_SYSTEMES_PAR_SECTEUR`
configurables).

Réserve reprise de la session `capture-rapports` : ces chiffres viennent
d'un Mac ARM où `mysql:5` tourne sous qemu (pénalisé), avec un CPU plus
rapide qu'un runner GitHub Actions. C'est un ordre de grandeur, pas une
prévision de CI.
