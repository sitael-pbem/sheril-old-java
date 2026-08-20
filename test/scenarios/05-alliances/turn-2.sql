-- diploI est connue depuis la fin du tour 1 : creer_alliance devient
-- acceptable. creer_alliance prend (NUMERO, ALLIANCE nom, SECRET, TYPE,
-- DROITS). SECRET = 1 signifie non secrète : ReceptionOrdres.creer_alliance
-- passe (tInt(o[1]) == 0) au paramètre "secrete". TYPE 0 = démocratique
-- (Const.ALLIANCE_TYPE_DEMOCRATIQUE, Const.java:239). Le concepteur devient
-- automatiquement dirigeant à la création (Alliance.java:409), quel que
-- soit le type.
INSERT INTO creer_alliance (NUMERO, ALLIANCE, SECRET, TYPE, DROITS)
VALUES (@NUM(Chef)@, 'Pacte du Nord', 1, 0, 0);

INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Membre)@, 'Membre attend.');
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Banni)@,  'Banni attend.');
