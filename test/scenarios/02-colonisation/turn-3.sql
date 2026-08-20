-- raffineI est connue depuis la fin du tour 2 (dump-tour-2.txt) : on met en
-- chantier la station d'unité energétique elle-même, sur une planète de la
-- capitale.
INSERT INTO construire (NUMERO, SYSTEME, CONSTRUCTION, NOMBRE, PLANETE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 'raffineI', 1, 0);

-- Le domaine technologique (100% du budget, voir turn-1.sql) n'a plus de
-- cible depuis que raffineI est acquise : on le réoriente vers gestplaI,
-- indispensable à modifier_taxation_planete (Commandant.java:2851-2853,
-- "if (!estTechnologieConnue("gestplaI")) return ajouterErreur(...)"),
-- constaté à l'exploration après un premier essai de taxation resté sans
-- effet et sans erreur visible dans le rapport (Univers.ajouterErreur écrit
-- dans le registre ORDRES_NON_CONFORMES, pas dans le rapport XML du
-- commandant). gestplaI est elle aussi de niveau 0 sans parent
-- (ListeParents.gestplaI = null), cherchable au tour 1 par tout commandant
-- (même règle que raffineI et stratcoI), coûte 50 points de recherche
-- (ListeTechnologique.java, candidate la moins chère avec diploI/progcoI).
INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Colon)@, 'gestplaI', 100);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
