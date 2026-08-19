-- La stratégie "Assaut" existe depuis le tour 2 : la flotte 0 d'Alpha part en
-- assaut sur la capitale de Beta.
--
-- Directive ciblée sur Beta, pas "attaque toutes les flottes" : la capitale
-- d'un commandant reste gardée par une flotte neutre (garnison du système,
-- toujours présente). DIRECTIVE_FLOTTE_ATTAQUE_TOUTE_FLOTTES (3) engage la
-- PREMIÈRE flotte hostile trouvée sur la case puis s'arrête net (le
-- combat consomme la directive, Combat.attaqueFlotte:239 sort dès que la
-- directive de l'attaquant est retombée à neutre) : vérifié, elle ne
-- combat que la garnison neutre et ignore Beta, dont les 8 lignes de
-- flotte restent inchangées à l'identique. DIRECTIVE_FLOTTE_ATTAQUE_JOUEUR
-- (8), elle, cible un commandant précis
-- (Combat.resolutionAttaqueFlotteJoueur ne retient que les flottes de ce
-- commandant) : encodée dans la colonne DIRECTIVE comme
-- "directive + 100 * numéro_cible" (Flotte.nombreDonneDirective /
-- directiveDonneNombre), d'où "8 + 100 * @NUM(Beta)@" ci-dessous. Valeur de
-- base de la directive : Const.java:442-450.
--
-- PIÈGE DE COLONNES (voir l'en-tête de test/harness/lib.sh) : POSX porte en
-- réalité la composante Y de la position construite côté moteur, et POSY la
-- composante X (ReceptionOrdres.deplacer_flotte construit
-- "new Position(GALAXIE, POSX, POSY)", et Position(gala, y, x) range son
-- premier argument dans pos[0] = Y). Pour atterrir sur la capitale de Beta,
-- lue "g_Y_X" dans le dump, on écrit donc POSX = @CAPY(Beta)@ et
-- POSY = @CAPX(Beta)@, pas l'inverse.
INSERT INTO deplacer_flotte (NUMERO, NUMFLOTTE, POSX, POSY, GALAXIE, DIRECTIVE, STRATEGIE)
VALUES (@NUM(Alpha)@, @FLOTTE(Alpha,0)@, @CAPY(Beta)@, @CAPX(Beta)@, @CAPG(Beta)@, 8 + 100 * @NUM(Beta)@, 'Assaut');

-- Beta rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Beta)@, 'Beta ne fait rien.');
