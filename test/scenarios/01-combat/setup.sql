-- Deux commandants de races différentes.
--
-- ATTENTION, aa_vaisseaux n'est PAS la flotte de départ, et ce fichier sert de
-- gabarit : Flotte.choixFlotteDeDepart (Flotte.java:257-289) lit VAISSEAU comme
-- un INDICE DE QUOTA de 1 à 5 (1 Intercepteur, 2 Chasseur, 3 Fregate,
-- 4 Eclaireur, 5 Grand Bombardier) et ignore silencieusement toute autre
-- valeur, puis répartit une flotte de taille imposée. Les deux lignes
-- ci-dessous ne donnent donc pas dix frégates : le golden du tour 1 rend
-- 69 vaisseaux (20 Chasseur, 20 Fregate, 20 Grand Bombardier, 6 Intercepteur,
-- 3 Eclaireur). Le même scénario sans aucune ligne aa_vaisseaux en rendrait 68 :
-- l'écart total de ces deux lignes est d'UN vaisseau.
-- L'ADRESSE sert de clé de jointure entre aa_inscription et aa_vaisseaux,
-- et doit passer InternetAddress.parse (ProductionOrdres.java:468).
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Alpha', 'alpha@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Beta',  'beta@sheril.test',  1, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('alpha@sheril.test', 3, 10);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('beta@sheril.test',  3, 10);
