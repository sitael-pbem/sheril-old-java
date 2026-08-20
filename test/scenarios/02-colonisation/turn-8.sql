-- Retour à une taxation nulle : le dump du dernier tour doit montrer l'effet
-- des deux réglages successifs sur la stabilité de la planète éradiquée et
-- repeuplée au tour 6 (turn-6.sql).
INSERT INTO modifier_taxation_planete (NUMERO, SYSTEME, TAXE, PLANETE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 0, 0);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
