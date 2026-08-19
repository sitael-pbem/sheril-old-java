-- L'acheteur enchérit sur les deux offres. acheter_galactique prend
-- (NUMERO, v0 id offre, v1 montant, v2 destination).
INSERT INTO acheter_galactique (NUMERO, v0, v1, v2)
VALUES (@NUM(Acheteur)@, @OFFRE(Vendeur1,0)@, 300, '@CAP(Acheteur)@');

INSERT INTO acheter_galactique (NUMERO, v0, v1, v2)
VALUES (@NUM(Acheteur)@, @OFFRE(Vendeur2,0)@, 300, '@CAP(Acheteur)@');
