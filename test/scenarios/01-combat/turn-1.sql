-- Alpha alloue tout son budget de recherche à la stratégie de combat.
-- creer_strategie exige la technologie "stratcoI" (Commandant.java:3838-3840),
-- qu'aucune race ne connaît de départ (Const.RACE_TECHNOLOGIES) et qu'aucune
-- table d'ordres ne permet d'accorder directement : le seul chemin est la
-- recherche. Elle se résout en fin de tour, dans DeroulementDuTour, après la
-- réception des ordres (donc après un éventuel creer_strategie du même tour)
-- et après la résolution des combats : une technologie apprise au tour N
-- n'est disponible qu'à partir du tour N+1. D'où l'étalement de ce scénario
-- sur plusieurs tours.
--
-- Deux affectations distinctes sont nécessaires (Commandant.java:606-619,
-- 1739-1771) : POURCENTAGE de modifier_budget répartit le REVENU d'une
-- possession entre domaines de dépense (BUDGET = 0 = domaine technologique,
-- Const.DOMAINES_BUDGET_TECHNOLOGIQUE), tandis qu'AFFECTATION de
-- affecter_recherche répartit ce budget technologique déjà obtenu entre les
-- technologies en cours de recherche. Sans le premier, le second reste à 0
-- point accumulé quel que soit son pourcentage : vérifié, sans
-- modifier_budget, commandant.1.recherche.stratcoI restait à "100/0" après
-- deux tours.
INSERT INTO modifier_budget (NUMERO, SYSTEME, BUDGET, POURCENTAGE)
VALUES (@NUM(Alpha)@, '@CAP(Alpha)@', 0, 100);

INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Alpha)@, 'stratcoI', 100);

-- Beta doit rendre un ordre à chaque tour, sous peine d'élimination pour
-- inactivité (ProductionOrdres.produireRegistre : un commandant humain est
-- supprimé quand dernierTourRendu < tour courant - 4 ; vécu ici, "Supression
-- du commandant Beta (2)" au tour 5 d'un premier essai à 5 tours sans aucun
-- ordre de Beta). ecrire_article n'a aucun effet sur l'état du jeu
-- (Univers.ajouterArticle), c'est le seul moyen de garder Beta actif sans
-- rien lui faire faire.
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Beta)@, 'Beta ne fait rien.');
