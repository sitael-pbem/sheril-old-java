-- Les deux autres demandent à adhérer, le chef valide les deux dans le même
-- tour. L'adhésion n'aboutit que si l'ordre valider_adhesion_alliance du
-- dirigeant existe dans le même tour (ReceptionOrdres.adherer_alliance,
-- qui vérifie la présence de la ligne via existenceOrdre, pas son
-- traitement préalable : les deux tables peuvent donc être posées le même
-- tour, contrairement au piège général de lib.sh sur les dépendances
-- inter-tables).
INSERT INTO adherer_alliance (NUMERO, ALLIANCE) VALUES (@NUM(Membre)@, 0);
INSERT INTO adherer_alliance (NUMERO, ALLIANCE) VALUES (@NUM(Banni)@, 0);

INSERT INTO valider_adhesion_alliance (NUMERO, POSTULANT, ALLIANCE)
VALUES (@NUM(Chef)@, @NUM(Membre)@, 0);
INSERT INTO valider_adhesion_alliance (NUMERO, POSTULANT, ALLIANCE)
VALUES (@NUM(Chef)@, @NUM(Banni)@, 0);
