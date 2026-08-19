// Sérialisation texte canonique de l'état de l'univers.
// Sert de référence de non-régression et d'outil de diagnostic.
// Aucune logique de jeu ici : cette classe lit, elle ne modifie rien.

package zIgzAg.jeu.oceane;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class DumpEtat {

	private static final Comparator<Position> PAR_POSITION = new Comparator<Position>() {
		public int compare(Position a, Position b) {
			int r = Integer.compare(a.getNumeroGalaxie(), b.getNumeroGalaxie());
			if (r != 0)
				return r;
			r = Integer.compare(a.getY(), b.getY());
			if (r != 0)
				return r;
			return Integer.compare(a.getX(), b.getX());
		}
	};

	private DumpEtat() {
	}

	public static void ecrire(String fichier, boolean complet) throws IOException {
		new Univers(true, "dumpState");
		StringBuilder sb = new StringBuilder();
		sb.append("tour = ").append(Univers.getTour()).append('\n');
		ecrireCommandants(sb, complet);
		ecrireSystemes(sb, complet);
		ecrireAlliances(sb);
		ecrireMarche(sb);
		Files.write(Paths.get(fichier), sb.toString().getBytes(StandardCharsets.UTF_8));
	}

	// un flottant se formate toujours en Locale.ROOT, sinon la virgule
	// décimale de la locale française rendrait le dump dépendant de
	// l'environnement.
	private static String f(float valeur) {
		return String.format(Locale.ROOT, "%.2f", valeur);
	}

	private static String pos(Position p) {
		return (p == null) ? "-" : p.toString();
	}

	private static void ecrireCommandants(StringBuilder sb, boolean complet) {
		Commandant[] cs = Univers.getListeCommandants();
		Arrays.sort(cs, new Comparator<Commandant>() {
			public int compare(Commandant a, Commandant b) {
				return Integer.compare(a.getNumero(), b.getNumero());
			}
		});
		for (int i = 0; i < cs.length; i++) {
			Commandant c = cs[i];
			boolean resume = !complet && (c.getNumero() == 0);
			String p = "commandant." + c.getNumero();
			sb.append(p).append(".nom = ").append(c.getNom()).append('\n');
			sb.append(p).append(".race = ").append(c.getRace()).append('\n');
			sb.append(p).append(".humain = ").append(c.estJoueurHumain()).append('\n');
			sb.append(p).append(".centaures = ").append(f(c.getCentaures())).append('\n');
			sb.append(p).append(".reputation = ").append(c.getReputation()).append('\n');
			sb.append(p).append(".pointsDeVictoire = ").append(c.getPointsDeVictoire()).append('\n');
			sb.append(p).append(".capitale = ").append(pos(c.getCapitale())).append('\n');
			sb.append(p).append(".possessions = ").append(c.getNombrePossessions()).append('\n');
			sb.append(p).append(".flottes = ").append(c.getNombreDeFlottes()).append('\n');

			if (!resume) {
				String[] technos = c.listeTechnologiesNonPubliquesConnues();
				Arrays.sort(technos);
				sb.append(p).append(".technologies = ").append(String.join(",", technos)).append('\n');

				String[] recherches = c.recherchesActuelles();
				Arrays.sort(recherches);
				for (int j = 0; j < recherches.length; j++) {
					String code = recherches[j];
					sb.append(p).append(".recherche.").append(code).append(" = ")
							.append(c.pourcentageAffecte(code)).append('/')
							.append(c.nombreDePointsDeRecherche(code)).append('\n');
				}

				Position[] domaine = c.listePossession();
				Arrays.sort(domaine, PAR_POSITION);
				for (int j = 0; j < domaine.length; j++)
					ecrirePossession(sb, p, domaine[j], c.getPossession(domaine[j]));
			}

			ecrireFlottes(sb, p, c, resume);
		}
	}

	private static void ecrirePossession(StringBuilder sb, String p, Position pos, Possession poss) {
		String q = p + ".possession." + pos(pos);
		sb.append(q).append(".politique = ").append(poss.getPolitique()).append('\n');
		for (int d = 0; d < Const.NB_DOMAINES_BUDGET; d++)
			sb.append(q).append(".budget.").append(d).append(" = ").append(poss.getBudget(d)).append('\n');
		int[] marchandises = poss.listeNumerosMarchandises();
		Arrays.sort(marchandises);
		for (int k = 0; k < marchandises.length; k++) {
			int m = marchandises[k];
			sb.append(q).append(".marchandise.").append(m).append(" = ")
					.append(poss.getPrixMarchandise(m)).append('/')
					.append(poss.getQuantiteMarchandise(m)).append('\n');
		}
	}

	private static void ecrireFlottes(StringBuilder sb, String p, Commandant c, boolean resume) {
		Map.Entry<Integer, Flotte>[] flottes = c.listeFlottesEtNumeros();
		Arrays.sort(flottes, new Comparator<Map.Entry<Integer, Flotte>>() {
			public int compare(Map.Entry<Integer, Flotte> a, Map.Entry<Integer, Flotte> b) {
				return Integer.compare(a.getKey(), b.getKey());
			}
		});
		for (int j = 0; j < flottes.length; j++) {
			Flotte fl = flottes[j].getValue();
			String q = p + ".flotte." + flottes[j].getKey();
			sb.append(q).append(".position = ").append(pos(fl.getPosition())).append('\n');
			sb.append(q).append(".vaisseaux = ").append(fl.getNombreDeVaisseaux()).append('\n');
			if (resume)
				continue;
			sb.append(q).append(".nom = ").append(fl.getNom()).append('\n');
			sb.append(q).append(".direction = ").append(pos(fl.getDirection())).append('\n');
			sb.append(q).append(".directive = ").append(fl.getDirectiveComplete()).append('\n');
			sb.append(q).append(".strategie = ").append(fl.getStrategie()).append('\n');
			sb.append(q).append(".puissance = ").append(fl.getPuissance()).append('\n');
			Map.Entry<String, Integer>[] types = fl.listeVaisseauxParType();
			Arrays.sort(types, new Comparator<Map.Entry<String, Integer>>() {
				public int compare(Map.Entry<String, Integer> a, Map.Entry<String, Integer> b) {
					return a.getKey().compareTo(b.getKey());
				}
			});
			for (int k = 0; k < types.length; k++)
				sb.append(q).append(".vaisseau.").append(types[k].getKey()).append(" = ")
						.append(types[k].getValue()).append('\n');
		}
	}

	private static void ecrireSystemes(StringBuilder sb, boolean complet) {
		Position[] positions = Univers.listePositionsSystemes();
		Arrays.sort(positions, PAR_POSITION);
		for (int i = 0; i < positions.length; i++) {
			Systeme s = Univers.getSysteme(positions[i]);
			String p = "systeme." + pos(positions[i]);
			sb.append(p).append(".nom = ").append(s.getNom()).append('\n');
			sb.append(p).append(".etoile = ").append(s.getTypeEtoile()).append('\n');
			// getProprios() reprend getProprio() planète par planète, donc -1
			// pour les planètes sans propriétaire. Or -1 est le joker « tous
			// propriétaires » de getStockMinerai, getPopulation et getTaxation :
			// dumper ce numéro écrirait des agrégats de tout le système sous une
			// clé qui prétend désigner un propriétaire. On l'écarte.
			int[] proprios = s.getProprios();
			Arrays.sort(proprios);
			StringBuilder liste = new StringBuilder();
			for (int j = 0; j < proprios.length; j++) {
				if (proprios[j] < 0)
					continue;
				if (liste.length() > 0)
					liste.append(',');
				liste.append(proprios[j]);
			}
			sb.append(p).append(".proprios = ").append(liste).append('\n');
			for (int j = 0; j < proprios.length; j++) {
				if (proprios[j] < 0)
					continue;
				sb.append(p).append(".proprio.").append(proprios[j]).append(".minerai = ")
						.append(s.getStockMinerai(proprios[j])).append('\n');
				sb.append(p).append(".proprio.").append(proprios[j]).append(".population = ")
						.append(s.getPopulation(proprios[j])).append('\n');
				sb.append(p).append(".proprio.").append(proprios[j]).append(".taxation = ")
						.append(s.getTaxation(proprios[j])).append('\n');
			}
			Planete[] planetes = s.getPlanetes();
			for (int j = 0; j < planetes.length; j++)
				ecrirePlanete(sb, p, j, planetes[j], complet);
		}
	}

	private static void ecrirePlanete(StringBuilder sb, String p, int index, Planete pl, boolean complet) {
		// Le critère est bien « >= 1 » et non « >= 0 », malgré les apparences.
		// Le commandant neutre porte le numéro 0 et possède la totalité de
		// l'univers à l'initialisation : un filtre « >= 0 » ne retirerait donc
		// aucune planète (mesuré à 4525 planètes sur 4525 en univers neuf) et
		// ne serait pas un critère. On ne détaille ici que les planètes d'un
		// vrai joueur, et les planètes peuplées que personne ne possède
		// (proprio négatif). Les planètes du neutre restent couvertes par les
		// agrégats systeme.<pos>.proprio.0.* écrits par ecrireSystemes, et
		// --complet les détaille toutes pour le diagnostic.
		boolean interessante = (pl.getProprio() >= 1) || ((pl.getProprio() < 0) && pl.estHabite());
		if (!complet && !interessante)
			return;
		String q = p + ".planete." + index;
		sb.append(q).append(".nom = ").append(pl.getNom()).append('\n');
		sb.append(q).append(".proprio = ").append(pl.getProprio()).append('\n');
		sb.append(q).append(".taille = ").append(pl.getTaille()).append('\n');
		sb.append(q).append(".type = ").append(pl.getType()).append('\n');
		sb.append(q).append(".terraformation = ").append(pl.getTerraformation()).append('\n');
		sb.append(q).append(".minerai = ").append(pl.getStockMinerai()).append('\n');
		sb.append(q).append(".taxation = ").append(pl.getTaxation()).append('\n');
		sb.append(q).append(".stabilite = ").append(pl.getStabilite()).append('\n');
		sb.append(q).append(".revolte = ").append(pl.getRevolte()).append('\n');
		for (int race = 0; race < Const.NB_RACES; race++) {
			int pop = pl.getPopActuelle(race);
			if (pop > 0)
				sb.append(q).append(".population.").append(race).append(" = ").append(pop).append('\n');
		}
	}

	private static void ecrireAlliances(StringBuilder sb) {
		Alliance[] as = Univers.getListeAlliances();
		Arrays.sort(as, new Comparator<Alliance>() {
			public int compare(Alliance a, Alliance b) {
				return Integer.compare(a.getNumero(), b.getNumero());
			}
		});
		for (int i = 0; i < as.length; i++) {
			Alliance a = as[i];
			String p = "alliance." + a.getNumero();
			sb.append(p).append(".nom = ").append(a.getNom()).append('\n');
			sb.append(p).append(".secrete = ").append(a.estSecrete()).append('\n');
			sb.append(p).append(".type = ").append(a.getDescriptionType(Locale.FRENCH)).append('\n');
			sb.append(p).append(".droits = ").append(f(a.getDroitsEntree())).append('\n');
			sb.append(p).append(".concepteur = ").append(a.getNumeroConcepteur()).append('\n');
			sb.append(p).append(".dirigeant = ").append(a.getNumeroDirigeant()).append('\n');
			Commandant[] membres = a.getAdherents();
			List<Integer> nums = new ArrayList<Integer>(membres.length);
			for (int j = 0; j < membres.length; j++)
				nums.add(membres[j].getNumero());
			java.util.Collections.sort(nums);
			StringBuilder liste = new StringBuilder();
			for (int j = 0; j < nums.size(); j++) {
				if (j > 0)
					liste.append(',');
				liste.append(nums.get(j));
			}
			sb.append(p).append(".membres = ").append(liste).append('\n');
		}
	}

	private static void ecrireMarche(StringBuilder sb) {
		List<OffreMarche> offres = new ArrayList<OffreMarche>(Univers.getListeOffresMarche());
		java.util.Collections.sort(offres, new Comparator<OffreMarche>() {
			public int compare(OffreMarche a, OffreMarche b) {
				return Integer.compare(a.getId(), b.getId());
			}
		});
		for (int i = 0; i < offres.size(); i++) {
			OffreMarche o = offres.get(i);
			String p = "offre." + o.getId();
			sb.append(p).append(".vendeur = ").append(o.getNumeroVendeur()).append('\n');
			sb.append(p).append(".origine = ").append(pos(o.getPositionOrigine())).append('\n');
			sb.append(p).append(".code = ").append(o.getCodeMarchandise()).append('\n');
			sb.append(p).append(".quantite = ").append(o.getQuantite()).append('\n');
			sb.append(p).append(".prix = ").append(o.getPrixTotal()).append('\n');
			sb.append(p).append(".tourFin = ").append(o.getTourFin()).append('\n');
		}
	}
}
