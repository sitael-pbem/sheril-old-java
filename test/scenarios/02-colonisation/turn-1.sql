-- Colon alloue tout son budget de recherche à raffineI. Le Colonisateur a
-- pour composant moteurI (marchandise "unité energétique", index 10,
-- ListeMarchandises.moteurI = {{10,1}}), qu'aucun commandant neuf ne possède
-- en stock (seul un minerai de départ est accordé, Joueur.java:370-372) :
-- constaté à l'exploration, le premier essai de "construire" un Colonisateur
-- échouait chaque tour avec "manque de marchandise (unité energétique)".
-- raffineI (station d'unité energétique) est de niveau 0, sans parent
-- (ListeParents.raffineI = null), donc cherchable au tour 1 par tout
-- commandant (même règle que stratcoI dans 01-combat), coûte 100 points de
-- recherche (ListeTechnologique.java:388) et ne consomme lui-même aucune
-- marchandise (ListeMarchandises.raffineI = null).
INSERT INTO modifier_budget (NUMERO, SYSTEME, BUDGET, POURCENTAGE)
VALUES (@NUM(Colon)@, '@CAP(Colon)@', 0, 100);

INSERT INTO affecter_recherche (NUMERO, TECHNOLOGIE, AFFECTATION)
VALUES (@NUM(Colon)@, 'raffineI', 100);

-- Temoin rend un ordre chaque tour pour ne pas être éliminé pour inactivité
-- (ProductionOrdres.produireRegistre, cf. 01-combat/turn-1.sql).
INSERT INTO ecrire_article (NUMERO, ARTICLE) VALUES (@NUM(Temoin)@, 'Temoin ne fait rien.');
