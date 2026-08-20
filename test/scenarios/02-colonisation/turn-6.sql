-- Le Colonisateur est disponible depuis la fin du tour 5 (dump-tour-5.txt) :
-- même piège général que la construction et la recherche (test/harness/lib.sh
-- en-tête), il n'était pas utilisable au tour où il a été mis en chantier.
-- utiliser_colonisateur prend (NUMERO, FLOTTE, PLANETE), divers/base_sheril.sql:568-574.
--
-- Cible : la planète 0 du système de la capitale, "Yo 1", que Colon possède
-- déjà (Commandant.coloniserPlanetes n'exige que estProprio, pas l'absence
-- de population, Commandant.java:3592) et qui est habitée par la race 1
-- depuis la création du commandant (population.1 = 114 dans
-- golden/dump-tour-1.txt).
--
-- Contrainte structurelle du moteur, pas un artefact de cette graine :
-- utiliser_colonisateur ne peut JAMAIS faire changer une planète de
-- propriétaire. Commandant.coloniserPlanetes rejette toute cible qui n'est
-- pas déjà estProprio(numero) (Commandant.java:3592), et une planète
-- possédée mais inhabitée à la création ne peut pas exister pour les races
-- 0 à 4 : Joueur.creerCommandant peuple automatiquement, dès la création,
-- toute planète du système capital dont meilleurPop() != -1
-- (Joueur.java:376-381) ; meilleurPop() ne rend -1 que si
-- calculeMaxPopDeBase(race) == 0 pour les races 0 à Const.NB_RACES-2
-- (Planete.java:827-838) ; et peutEtreColoniseParRace, la condition de
-- succès de utiliser_colonisateur, c'est exactement calculeMaxPop(race) > 0
-- avec calculeMaxPop == calculeMaxPopDeBase (Planete.java:753-755,
-- 807-814). Une planète non peuplée à la création n'est donc colonisable
-- par aucune des races 0 à 4 (seule une planète habitable par la seule
-- race 5, hors du scope de ce scénario, y échapperait). L'unique cible
-- possible ici est donc déjà habitée, et utiliser_colonisateur y déclenche
-- une ÉRADICATION (population remise à zéro, réputation -300, stabilité
-- -10, Commandant.java:3608-3621) suivie d'un repeuplement par la race de
-- l'équipage du Colonisateur, qui est la race majoritaire du système
-- (Possession.java:559), ici la race 1 aussi : le repeuplement réussit à
-- coup sûr.
INSERT INTO utiliser_colonisateur (NUMERO, FLOTTE, PLANETE)
VALUES (@NUM(Colon)@, @FLOTTE(Colon,0)@, 0);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
