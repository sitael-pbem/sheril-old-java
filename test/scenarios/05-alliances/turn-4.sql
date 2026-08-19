-- Les trois membres votent pour élire Membre dirigeant. Alliance.traiterVotes
-- (appelé depuis ReceptionOrdres au moment de traiter exclure_alliance,
-- ReceptionOrdres.java:450-451) tranche dans le même tour : majorité simple
-- (max >= nbMembres/2, Alliance.java:304).
INSERT INTO nommer_dirigeant (NUMERO, ALLIANCE, DIRIGEANT) VALUES (@NUM(Chef)@,   0, @NUM(Membre)@);
INSERT INTO nommer_dirigeant (NUMERO, ALLIANCE, DIRIGEANT) VALUES (@NUM(Membre)@, 0, @NUM(Membre)@);
INSERT INTO nommer_dirigeant (NUMERO, ALLIANCE, DIRIGEANT) VALUES (@NUM(Banni)@,  0, @NUM(Membre)@);
