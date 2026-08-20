-- Alpha connaît maintenant "stratcoI" (recherche affectée au tour 1) : la
-- stratégie de combat peut être créée. Elle n'est PAS assignée à une flotte
-- dans ce même tour : contrainte générale du harnais documentée en en-tête
-- de test/harness/lib.sh, une stratégie créée ce tour n'existe pas encore
-- pour un deplacer_flotte du même tour. Voir turn-3.sql.
-- Les valeurs d'AGRESSIVITE viennent de Const.java:603-608.
INSERT INTO creer_strategie (NUMERO, NOM, AGRESSIVITE, CIBLE)
VALUES (@NUM(Alpha)@, 'Assaut', 4, 0);

-- Beta rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (voir turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Beta)@, 'Beta ne fait rien.');
