-- Deux commandants de races différentes, dix chasseurs standard chacun.
-- L'ADRESSE sert de clé de jointure entre aa_inscription et aa_vaisseaux,
-- et doit passer InternetAddress.parse (ProductionOrdres.java:468).
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Alpha', 'alpha@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Beta',  'beta@sheril.test',  1, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('alpha@sheril.test', 3, 10);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('beta@sheril.test',  3, 10);
