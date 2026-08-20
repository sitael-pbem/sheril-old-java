-- Savant alloue tout son budget de recherche à progcoI, technologie de
-- niveau 0 sans parent (ListeTechnologique.progcoI, parents = null), donc
-- cherchable au tour 1 par tout commandant (même règle que stratcoI dans
-- 01-combat et gestplaI dans 02-colonisation). Coût affiché 50 points, coût
-- effectif 200 points (Const.MODIFICATEUR_DIFFICULTE_RECHERCHE = 4).
-- Deux affectations distinctes nécessaires (Commandant.java:606-619,
-- 1739-1771) : BUDGET = 0 du domaine technologique via modifier_budget
-- alimente le budget technologique, AFFECTATION de affecter_recherche
-- répartit ce budget entre les technologies en cours de recherche. Sans le
-- premier, le second reste à 0 point accumulé. Les deux ordres ne
-- s'enchaînent pas dans cet ordre au sein du tour : affecter_recherche est
-- traité avant modifier_budget (index 12 contre 19,
-- Const.ORDRE_AFFECTER_RECHERCHE et Const.ORDRE_MODIFIER_BUDGET,
-- Const.java:754,756), c'est la résolution de fin de tour
-- (resolutionProgressionRecherche, Commandant.java:1739-1771) qui combine
-- les deux, après que tous les ordres du tour ont été traités.
INSERT INTO modifier_budget (NUMERO, SYSTEME, BUDGET, POURCENTAGE)
VALUES (@NUM(Savant)@, '@CAP(Savant)@', 0, 100);

INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Savant)@, 'progcoI', 100);
