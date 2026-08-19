-- Trois commandants. Chef créera l'alliance et la dirigera jusqu'à
-- l'élection ; Membre et Banni la rejoignent, votent, puis Banni en est
-- exclu par les deux autres. L'ADRESSE sert de clé de jointure entre
-- aa_inscription et aa_vaisseaux, et doit passer InternetAddress.parse
-- (ProductionOrdres.java:468).
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Chef',    'chef@sheril.test',    0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Membre',  'membre@sheril.test',  1, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Banni',   'banni@sheril.test',   2, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('chef@sheril.test',   3, 3);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('membre@sheril.test', 3, 3);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('banni@sheril.test',  3, 3);
