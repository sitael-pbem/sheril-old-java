-- Chaque vendeur met en vente depuis sa capitale, une fois la production du
-- tour 1 creditee. vendre_galactique prend (NUMERO, v0 position, v1 code
-- marchandise, v2 quantite, v3 prix unitaire), cf. divers/base_sheril.sql.
--
-- ATTENTION AU FORMAT DU DUMP : DumpEtat.ecrirePossession ecrit
-- ".marchandise.<code> = <PRIX>/<QUANTITE>" (prix d'abord, quantite ensuite,
-- DumpEtat.java:111-113), l'inverse de ce qu'on lirait naivement. Apres un
-- seul tour de production (aucun ordre au tour 1), une possession de depart
-- ne detient que 1 a 3 unites de chaque marchandise (verifie :
-- commandant.1.possession.<capitale>.marchandise.7 = 49/1, soit prix 49,
-- quantite 1). Vendre 40 ou 50 unites a ce stade echoue silencieusement en
-- ER_COMMANDANT_VENTE_GALACTIQUE_0002 (aucune offre creee). La marchandise 7
-- est la seule presente avec au moins 1 unite aux DEUX capitales sous cette
-- graine ; on vend donc 1 unite chacun.
INSERT INTO vendre_galactique (NUMERO, v0, v1, v2, v3)
VALUES (@NUM(Vendeur1)@, '@CAP(Vendeur1)@', '7', 1, 10);

INSERT INTO vendre_galactique (NUMERO, v0, v1, v2, v3)
VALUES (@NUM(Vendeur2)@, '@CAP(Vendeur2)@', '7', 1, 10);
