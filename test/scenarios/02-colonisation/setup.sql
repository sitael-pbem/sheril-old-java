-- Deux commandants. Colon construira et emploiera un colonisateur ; Temoin
-- sert de témoin immobile et de second destinataire de rapport (aucune
-- interaction entre les deux, il ne fait que rendre un ordre à chaque tour
-- pour ne pas être éliminé pour inactivité, cf. 01-combat/turn-1.sql).
-- L'ADRESSE sert de clé de jointure entre aa_inscription et aa_vaisseaux, et
-- doit passer InternetAddress.parse (ProductionOrdres.java:468).
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Colon', 'colon@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Temoin', 'temoin@sheril.test', 2, 0);
