-- Chef alloue tout son budget de recherche à diploI, seule voie pour
-- connaître cette technologie (aucune race ne la connaît de départ). Coût
-- affiché 50 points, coût effectif 200 points
-- (Const.MODIFICATEUR_DIFFICULTE_RECHERCHE = 4), acquis en un tour à 100%
-- du budget technologique.
INSERT INTO modifier_budget (NUMERO, SYSTEME, BUDGET, POURCENTAGE)
VALUES (@NUM(Chef)@, '@CAP(Chef)@', 0, 100);

INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Chef)@, 'diploI', 100);

-- Membre et Banni n'ont encore aucune action liée à l'alliance (elle
-- n'existe pas avant le tour 2) : ils rendent un ordre neutre pour ne pas
-- être éliminés pour inactivité (ProductionOrdres.produireRegistre, cf.
-- 01-combat/turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Membre)@, 'Membre attend.');
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Banni)@,  'Banni attend.');
