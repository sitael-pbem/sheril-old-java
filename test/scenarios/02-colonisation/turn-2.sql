-- raffineI est en cours d'acquisition (points accumulés au tour 1) mais
-- n'est réellement connue qu'à la fin du tour 2 (résolution de la recherche
-- après réception des ordres, même piège que stratcoI dans 01-combat) :
-- aucun ordre de construction n'est donc encore possible ce tour-ci
-- (vérifié à l'exploration : "construire raffineI" soumis ici échoue avec
-- "vous ne pouvez construire ... raffineI").
-- Colon rend lui aussi un ordre chaque tour où il n'a rien d'autre à faire :
-- ProductionOrdres.produireRegistre élimine un commandant humain inactif
-- (dernierTourRendu < tour courant - 4), et Colon reste inactif plusieurs
-- tours de suite le temps que la recherche puis la construction se résolvent
-- (vécu à l'exploration : Colon supprimé au tour 8 faute d'ordre depuis le
-- tour 3).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Colon)@, 'Colon attend sa recherche.');
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
