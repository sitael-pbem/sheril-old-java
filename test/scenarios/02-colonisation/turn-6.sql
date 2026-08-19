-- Le Colonisateur est disponible depuis la fin du tour 5 (dump-tour-5.txt) :
-- même piège général que la construction et la recherche (test/harness/lib.sh
-- en-tête), il n'était pas utilisable au tour où il a été mis en chantier.
-- utiliser_colonisateur prend (NUMERO, FLOTTE, PLANETE), divers/base_sheril.sql:568-574.
-- Cible : la planète 0 du système de la capitale, "Yo 1", que Colon possède
-- déjà (Commandant.coloniserPlanetes n'exige que estProprio, pas l'absence
-- de population, Commandant.java:3592) et qui est habitée par la race 1
-- depuis la création du commandant (population.1 = 87 dans dump-tour-0.txt).
INSERT INTO utiliser_colonisateur (NUMERO, FLOTTE, PLANETE)
VALUES (@NUM(Colon)@, @FLOTTE(Colon,0)@, 0);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
