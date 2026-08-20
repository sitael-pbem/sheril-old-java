-- Deux commandants de races différentes, dix frégates demandées chacun.
--
-- ATTENTION, ce fichier sert de gabarit et le golden le contredit : Alpha part
-- avec 69 vaisseaux de composition variée, Beta avec exactement 10 Fregate
-- standard. Deux mécanismes se superposent, tous deux à connaître avant
-- d'écrire un aa_vaisseaux.
--
-- 1. aa_vaisseaux N'AJOUTE PAS des vaisseaux, il REMPLACE la flotte. VAISSEAU
--    est un indice de 1 à 5 dans une table de quotas nommés (1 Intercepteur,
--    2 Chasseur, 3 Fregate, 4 Eclaireur, 5 Grand Bombardier), et dès que la map
--    est non vide, Flotte.choixFlotteDeDepart remet TOUS les quotas à zéro
--    (Flotte.java:280-281, le tableau des défauts est remplacé par un tableau
--    neuf) avant d'appliquer les seuls indices présents. Demander
--    « 10 en indice 3 » donne donc 10 frégates et rien d'autre, pas 10 frégates
--    en plus du reste. Un indice hors de 1..5 est ignoré, donc une ligne unique
--    hors bornes donne une flotte VIDE, sans erreur.
--
-- 2. La PREMIÈRE ligne de aa_vaisseaux n'est jamais lue, quel que soit le
--    commandant. ProductionOrdres.java:493-495 fait r2.first() puis
--    while (r2.next()) : first() place déjà le curseur SUR la ligne 1, que le
--    premier next() saute. Le propriétaire de la PREMIÈRE LIGNE DE aa_vaisseaux
--    garde donc la flotte par défaut, quel que soit son rang dans
--    aa_inscription. C'est un bug moteur, pas une propriété du format, et il
--    vaut pour une vraie partie : ce joueur n'obtient pas la flotte qu'il a
--    demandée, sans le moindre message. Suivi en SHRL-54.
--
-- D'où l'asymétrie du golden : la ligne d'Alpha est la première de la table,
-- elle est perdue, Alpha garde les quotas par défaut ; celle de Beta est lue et
-- remplace tout. Vérifié aussi sur 05-alliances, trois lignes identiques, le
-- premier commandant à 68 vaisseaux et les deux autres à 3.
-- L'ADRESSE sert de clé de jointure entre aa_inscription et aa_vaisseaux,
-- et doit passer InternetAddress.parse (ProductionOrdres.java:468).
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Alpha', 'alpha@sheril.test', 0, 0);
INSERT INTO aa_inscription (NOM, ADRESSE, RACE, FLOTTE) VALUES ('Beta',  'beta@sheril.test',  1, 0);

INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('alpha@sheril.test', 3, 10);
INSERT INTO aa_vaisseaux (ADRESSE, VAISSEAU, NOMBRE) VALUES ('beta@sheril.test',  3, 10);
