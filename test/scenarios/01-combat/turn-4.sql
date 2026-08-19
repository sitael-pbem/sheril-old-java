-- Aucun ordre neuf pour Alpha : on laisse la flotte poursuivre sa route vers
-- la capitale de Beta.
-- Beta rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Beta)@, 'Beta ne fait rien.');
