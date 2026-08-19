-- Deux voix pour exclure Banni, mais UNE SEULE aurait suffi : le seuil est
-- nbVoix >= nbMembres / 2 en division entière, soit >= 1 pour trois membres.
-- Le second vote ne teste donc pas le seuil, il n'exerce que le cumul des voix.
-- Le plan initial lisait VOTE comme
-- un booléen ("1 = exclusion") : c'est faux, vérifié à l'exploration (un
-- premier essai a exclu Chef au lieu de Banni). ReceptionOrdres.exclure_alliance
-- transmet (o[0]=ALLIANCE, o[1]=VOTE) à Commandant.voterExclusionCommandant
-- (int num, int cible) : VOTE porte le NUMÉRO du commandant visé, pas un
-- indicateur binaire (Alliance.traiterVoteExclusion, seuil identique à
-- l'élection : nbVoix >= nbMembres/2, Alliance.java:342).
INSERT INTO exclure_alliance (NUMERO, ALLIANCE, VOTE) VALUES (@NUM(Chef)@,   0, @NUM(Banni)@);
INSERT INTO exclure_alliance (NUMERO, ALLIANCE, VOTE) VALUES (@NUM(Membre)@, 0, @NUM(Banni)@);

INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Banni)@, 'Banni ne vote pas son exclusion.');
