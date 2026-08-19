-- Savant alloue tout son budget de recherche à progcoI, technologie de
-- niveau 0 sans parent (ListeTechnologique.progcoI, parents = null), donc
-- cherchable au tour 1 par tout commandant (même règle que stratcoI dans
-- 01-combat et gestplaI dans 02-colonisation). Coût affiché 50 points, coût
-- effectif 200 points (Const.MODIFICATEUR_DIFFICULTE_RECHERCHE = 4).
-- Deux affectations distinctes nécessaires (Commandant.java:606-619,
-- 1739-1771) : BUDGET = 0 du domaine technologique via modifier_budget
-- alimente le budget technologique, AFFECTATION de affecter_recherche
-- répartit ce budget déjà obtenu entre les technologies en cours de
-- recherche. Sans le premier, le second reste à 0 point accumulé.
INSERT INTO modifier_budget (NUMERO, SYSTEME, BUDGET, POURCENTAGE)
VALUES (@NUM(Savant)@, '@CAP(Savant)@', 0, 100);

INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Savant)@, 'progcoI', 100);
