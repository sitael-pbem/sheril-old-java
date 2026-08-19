-- Aucun ordre neuf pour Alpha : on laisse le combat se résoudre s'il ne
-- l'est pas déjà. Le tour 5 a vu la flotte d'Alpha atteindre la position
-- exacte de la capitale de Beta dans le dump, sans que la flotte de Beta
-- n'ait encore subi de dégâts à ce même tour : Combat.resolutionCombats()
-- s'exécute avant que le déplacement du tour ne soit pleinement appliqué,
-- le premier tour où les deux flottes sont effectivement co-présentes pour
-- le combat est donc celui-ci.
-- Beta rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Beta)@, 'Beta ne fait rien.');
