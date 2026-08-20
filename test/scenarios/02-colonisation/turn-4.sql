-- La station raffineI a été construite pendant le tour 3 (rapport du tour 4)
-- et produit désormais de l'unité energétique chaque tour (visible dans
-- dump-tour-4.txt : commandant.1.possession.0_10_17.marchandise.10 = 45/5,
-- 5 unités accumulées). Rien à faire ce tour-ci que rendre un ordre neutre.
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Colon)@, 'Colon patiente, la station energétique produit.');
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
