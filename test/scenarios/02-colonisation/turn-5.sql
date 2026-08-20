-- Colon dispose d'assez d'unité energétique (5, un seul suffit pour le
-- Colonisateur, moteurI = ListeMarchandises.moteurI = {{10,1}}) : mise en
-- chantier du Colonisateur. Il rejoint la flotte 0 déjà présente sur le
-- système (vérifié à l'exploration : le Colonisateur apparaît dans
-- commandant.1.flotte.0.vaisseau.Colonisateur dès dump-tour-5.txt, résolu le
-- même tour que sa mise en chantier).
INSERT INTO construire (NUMERO, SYSTEME, CONSTRUCTION, NOMBRE, PLANETE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 'Colonisateur', 1, 0);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
