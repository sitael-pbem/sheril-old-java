-- Taxation maximale sur la planète tout juste éradiquée et repeuplée
-- (turn-6.sql), pour faire bouger la stabilité au tour suivant.
-- TAXATION_MAXIMALE vaut 5 (Const.java:196).
INSERT INTO modifier_taxation_planete (NUMERO, SYSTEME, TAXE, PLANETE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 5, 0);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
