#!/usr/bin/env python3
"""Substitue les marqueurs d'un fichier d'ordres depuis un dump d'etat.

Usage: resolve-markers.py <dump.txt> <ordres.sql>
Ecrit le resultat sur la sortie standard.
Un marqueur non resolu fait sortir en code 1, jamais en avertissement.
"""
import re
import sys

MARQUEUR = re.compile(r"@([A-Z]+)\(([^)]*)\)@")

# DumpEtat rend cette chaine pour une position nulle (ex. un commandant sans
# capitale). La substituer dans un ordre SQL attendant une position produirait
# un ordre silencieusement absurde : c'est une erreur fatale, jamais une valeur
# comme une autre.
SENTINELLE_POSITION_NULLE = "-"


def charger(chemin):
    valeurs = {}
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            if " = " not in ligne:
                continue
            cle, valeur = ligne.rstrip("\n").split(" = ", 1)
            valeurs[cle] = valeur
    return valeurs


def numero_par_nom(valeurs, nom):
    # La cle doit etre exactement "commandant.<n>.nom" : une flotte porte elle
    # aussi une cle qui commence par "commandant." et finit par ".nom", et une
    # flotte homonyme d'un commandant repondrait a sa place.
    for cle, valeur in valeurs.items():
        parts = cle.split(".")
        if len(parts) == 3 and parts[0] == "commandant" and parts[2] == "nom" and valeur == nom:
            return parts[1]
    raise KeyError("aucun commandant nomme %r dans le dump" % nom)


def rangs(valeurs, prefixe, suffixe):
    """Numeros tries des cles de la forme <prefixe>.<n>.<suffixe>."""
    trouves = set()
    for cle in valeurs:
        if cle.startswith(prefixe + ".") and cle.endswith("." + suffixe):
            reste = cle[len(prefixe) + 1:-len(suffixe) - 1]
            if reste.isdigit():
                trouves.add(int(reste))
    return sorted(trouves)


def resoudre(valeurs, genre, args):
    parts = [a.strip() for a in args.split(",")]
    nom = parts[0]
    num = numero_par_nom(valeurs, nom)
    if genre == "NUM":
        return num
    if genre in ("CAP", "CAPG", "CAPY", "CAPX"):
        capitale = valeurs["commandant.%s.capitale" % num]
        if capitale == SENTINELLE_POSITION_NULLE:
            raise KeyError(
                "le marqueur de position pour le commandant %r (numero %s) "
                "n'a pas de resolution : sa capitale est nulle dans le dump" % (nom, num)
            )
        if genre == "CAP":
            return capitale
        g, y, x = capitale.split("_")
        return {"CAPG": g, "CAPY": y, "CAPX": x}[genre]
    if genre == "FLOTTE":
        rang = int(parts[1])
        numeros = rangs(valeurs, "commandant.%s.flotte" % num, "position")
        if rang >= len(numeros):
            raise KeyError("le commandant %r n'a que %d flotte(s)" % (nom, len(numeros)))
        return str(numeros[rang])
    if genre == "OFFRE":
        ids = sorted(
            int(cle.split(".")[1])
            for cle, valeur in valeurs.items()
            if cle.startswith("offre.") and cle.endswith(".vendeur") and valeur == num
        )
        rang = int(parts[1])
        if rang >= len(ids):
            raise KeyError("le commandant %r n'a que %d offre(s)" % (nom, len(ids)))
        return str(ids[rang])
    raise KeyError("marqueur inconnu: %s" % genre)


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    valeurs = charger(sys.argv[1])
    with open(sys.argv[2], encoding="utf-8") as f:
        texte = f.read()

    erreurs = []

    def remplacer(m):
        try:
            return resoudre(valeurs, m.group(1), m.group(2))
        except KeyError as e:
            # str(KeyError(...)) reintroduit des guillemets (repr de l'argument) :
            # on prend le message d'origine via e.args[0] pour un rendu propre.
            message = e.args[0] if e.args else str(e)
            erreurs.append("%s: %s" % (m.group(0), message))
            return m.group(0)

    resultat = MARQUEUR.sub(remplacer, texte)
    if erreurs:
        for e in erreurs:
            print("marqueur non resolu, " + e, file=sys.stderr)
        return 1
    if "@" in resultat and MARQUEUR.search(resultat):
        print("marqueur residuel apres substitution", file=sys.stderr)
        return 1
    sys.stdout.write(resultat)
    return 0


if __name__ == "__main__":
    sys.exit(main())
