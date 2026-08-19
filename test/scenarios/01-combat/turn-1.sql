-- Alpha se donne une stratégie agressive et lance sa flotte 0 sur la
-- capitale de Beta, en directive d'attaque de toutes les flottes.
-- Les valeurs de DIRECTIVE et d'AGRESSIVITE viennent de Const.java:422-431
-- et Const.java:583-588.
-- aa_inscription/aa_vaisseaux ne sont jamais vidées par produireRegistre
-- (ProductionOrdres.java:407) : sans ce nettoyage, le newRound du tour 1
-- retrouverait les mêmes lignes et recréerait Alpha et Beta une deuxième fois.
DELETE FROM aa_inscription;
DELETE FROM aa_vaisseaux;

INSERT INTO creer_strategie (NUMERO, NOM, AGRESSIVITE, CIBLE)
VALUES (@NUM(Alpha)@, 'Assaut', 4, 0);

INSERT INTO deplacer_flotte (NUMERO, NUMFLOTTE, POSX, POSY, GALAXIE, DIRECTIVE, STRATEGIE)
VALUES (@NUM(Alpha)@, @FLOTTE(Alpha,0)@, @CAPX(Beta)@, @CAPY(Beta)@, @CAPG(Beta)@, 3, 'Assaut');
