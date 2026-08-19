-- Aucun ordre neuf pour Alpha : on laisse le combat se résoudre s'il ne
-- l'est pas déjà.
-- Beta rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql). Si le combat a déjà éliminé Beta à ce stade, cet ordre
-- est silencieusement sans effet (plus aucun commandant pour le porter).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Beta)@, 'Beta ne fait rien.');
