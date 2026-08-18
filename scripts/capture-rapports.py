#!/usr/bin/env python3
"""Capture visuelle des rapports de commandants produits par le moteur.

Le moteur ecrit deja les rapports en HTML statique, un repertoire par
commandant et par tour :

    <PATH_DATA>/tour<N>/rapports/
        images/              <- rapport.css + les .gif/.jpg (Chemin.java:148)
        <numCommandant>tour<N>/
            RAPPORT.htm      <- frameset menu + principal (Rapport.java:950)
            menu.htm
            principal.htm
            detailF.htm      <- flotte
            detailT.htm      <- technologies
            combat.htm
            <position><num>P.htm / PO.htm / RE.htm, <num>A.htm ...

Ce script ne genere rien de nouveau : il rend ce qui existe. Pour chaque page
il produit un PNG (haut de page, pour la vignette) et un PDF (page entiere,
Chrome ne sait pas capturer une page longue en PNG), puis un index.html qui
donne une galerie parcourable, groupee par commandant.

Aucune dependance : uniquement python3 et un Chrome/Chromium local.

Usage :
    python3 scripts/capture-rapports.py data/tour3/rapports
    python3 scripts/capture-rapports.py data/tour3/rapports -o /tmp/visu -c 12
"""

from __future__ import annotations

import argparse
import concurrent.futures
import html
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Chemins Chrome usuels, dans l'ordre de preference.
CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
]

# Ordre de lecture d'un rapport : la frameset, puis le corps, puis les annexes.
# Tout ce qui n'est pas liste ici passe apres, en ordre alphabetique.
PAGE_ORDER = {
    "RAPPORT.htm": 0,
    "principal.htm": 1,
    "menu.htm": 2,
    "detailF.htm": 3,
    "detailT.htm": 4,
    "combat.htm": 5,
}

PAGE_LABELS = {
    "RAPPORT.htm": "Rapport (vue framee)",
    "principal.htm": "Principal",
    "menu.htm": "Menu",
    "detailF.htm": "Detail flotte",
    "detailT.htm": "Detail technologies",
    "combat.htm": "Detail combat",
}

# Noms des annexes, ou <position> vaut "galaxie_x_y" (Position.java:203) :
#   <position><numCommandant>P.htm  -> fiche planete        (Rapport.java:382)
#   <position><numCommandant>PO.htm -> planete observee     (Rapport.java:390)
#   <position>RE.htm                -> rapport d'espionnage (Rapport.java:476)
#   <numAlliance>A.htm              -> fiche alliance       (Rapport.java:386)
# La position et le numero de commandant sont colles sans separateur, et se
# terminent tous deux par des chiffres : aucune regex ne peut les separer.
# D'ou le decoupage par la fin, en s'appuyant sur le numero du repertoire.
ANNEXE_SUFFIXES = [("PO.htm", "Planete observee {0}", True),
                   ("P.htm", "Planete {0}", True),
                   ("RE.htm", "Espionnage {0}", False),
                   ("A.htm", "Alliance {0}", False)]

# <numCommandant>tour<N> : Rapport.java:755
DIR_RE = re.compile(r"^(?P<commandant>\d+)tour(?P<tour>\d+)$")


def trouver_chrome(explicite: str | None) -> str:
    if explicite:
        if not Path(explicite).exists():
            sys.exit(f"chrome introuvable : {explicite}")
        return explicite
    for candidat in CHROME_CANDIDATES:
        if Path(candidat).exists():
            return candidat
    trouve = shutil.which("google-chrome") or shutil.which("chromium")
    if trouve:
        return trouve
    sys.exit(
        "aucun Chrome/Chromium trouve. Passer --chrome <chemin> explicitement."
    )


def libelle_page(nom: str, num_commandant: str) -> str:
    if nom in PAGE_LABELS:
        return PAGE_LABELS[nom]
    for suffixe, gabarit, porte_le_numero in ANNEXE_SUFFIXES:
        if not nom.endswith(suffixe):
            continue
        reste = nom[: -len(suffixe)]
        if porte_le_numero and reste.endswith(num_commandant):
            reste = reste[: -len(num_commandant)]
        return gabarit.format(reste) if reste else nom
    return nom


def rang_page(nom: str) -> tuple[int, str]:
    return (PAGE_ORDER.get(nom, 99), nom)


def lister_commandants(racine: Path, filtre: set[str] | None) -> list[tuple[str, str, Path]]:
    """Retourne [(numCommandant, tour, repertoire)] trie par numero croissant."""
    trouves = []
    for entree in sorted(racine.iterdir()):
        if not entree.is_dir():
            continue
        m = DIR_RE.match(entree.name)
        if not m:
            continue  # images/, et tout repertoire hors convention
        num = m.group("commandant")
        if filtre and num not in filtre:
            continue
        trouves.append((num, m.group("tour"), entree))
    return sorted(trouves, key=lambda t: int(t[0]))


def capturer(chrome: str, source: Path, png: Path, pdf: Path, largeur: int,
             hauteur: int, budget_ms: int) -> tuple[bool, bool, str]:
    """Rend une page en PNG (viewport) et en PDF (page entiere).

    Chrome n'a pas d'equivalent CLI du "full page screenshot" : --screenshot
    est borne au viewport (verifie : une table de 200 lignes dans une fenetre
    de 1000x800 rend un PNG de 1000x800, tronque). Le PDF, lui, pagine la page
    entiere. D'ou les deux sorties : le PNG sert de vignette, le PDF fait foi.
    """
    png.parent.mkdir(parents=True, exist_ok=True)
    url = source.resolve().as_uri()
    erreurs = []

    commun = [
        chrome,
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--no-first-run",
        "--no-default-browser-check",
        "--allow-file-access-from-files",
        f"--virtual-time-budget={budget_ms}",
    ]

    def lancer(args, quoi):
        # Surtout pas capture_output : Chrome laisse des processus auxiliaires
        # qui heritent du pipe et le gardent ouvert, si bien que subprocess.run
        # attend longtemps apres la fin du rendu. Mesure sur une page de la
        # fixture : 2 s en DEVNULL contre plus de 90 s en PIPE.
        try:
            subprocess.run(
                commun + args + [url],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=90,
                check=False,
            )
        except subprocess.TimeoutExpired:
            erreurs.append(f"timeout {quoi}")

    lancer([f"--screenshot={png}", f"--window-size={largeur},{hauteur}"], "png")
    lancer(["--no-pdf-header-footer", f"--print-to-pdf={pdf}"], "pdf")

    ok_png = png.exists() and png.stat().st_size > 0
    ok_pdf = pdf.exists() and pdf.stat().st_size > 0
    return ok_png, ok_pdf, ", ".join(erreurs)


GABARIT_INDEX = """<!doctype html>
<meta charset="utf-8">
<title>Rapports {tour} - validation visuelle</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{ background:#10001d; color:#ccc; font:15px/1.5 system-ui,sans-serif; margin:0 0 4rem; }}
  header {{ padding:1.5rem 2rem; border-bottom:1px solid #2a1740; }}
  h1 {{ margin:0 0 .3rem; font-size:1.4rem; color:#1dddc9; }}
  .meta {{ color:#8a7ba8; font-size:.85rem; }}
  section {{ padding:1.5rem 2rem; border-bottom:1px solid #201033; }}
  h2 {{ margin:0 0 1rem; font-size:1.1rem; color:#ffb400; }}
  .grille {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:1.2rem; }}
  figure {{ margin:0; background:#180a28; border:1px solid #2a1740; border-radius:6px; overflow:hidden; }}
  figure img {{ display:block; width:100%; height:190px; object-fit:cover; object-position:top left; background:#000; }}
  figcaption {{ padding:.6rem .7rem; font-size:.82rem; }}
  figcaption b {{ display:block; color:#e8e0f5; font-weight:600; margin-bottom:.3rem; }}
  figcaption a {{ color:#64D200; text-decoration:none; margin-right:.7rem; }}
  figcaption a:hover {{ text-decoration:underline; }}
  .ko {{ color:#ec6c55; }}
</style>
<header>
  <h1>Rapports des commandants {tour}</h1>
  <p class="meta">{nb_cmd} commandant(s), {nb_pages} page(s) rendue(s) depuis <code>{source}</code>.
  La vignette montre le haut de page ; le PDF contient la page entiere.</p>
</header>
{sections}
"""

GABARIT_SECTION = """<section>
  <h2>Commandant {num}</h2>
  <div class="grille">
{figures}
  </div>
</section>
"""


def construire_index(sortie: Path, source: Path, tour: str,
                     par_commandant: dict[str, list[dict]]) -> Path:
    sections = []
    nb_pages = 0
    for num, pages in par_commandant.items():
        figures = []
        for page in pages:
            nb_pages += 1
            liens = []
            if page["png"]:
                liens.append(f'<a href="{html.escape(page["png"])}">png</a>')
            if page["pdf"]:
                liens.append(f'<a href="{html.escape(page["pdf"])}">pdf entier</a>')
            liens.append(f'<a href="{html.escape(page["src"])}">source</a>')
            if page["png"]:
                vignette = f'<img src="{html.escape(page["png"])}" alt="{html.escape(page["label"])}" loading="lazy">'
            else:
                vignette = '<img alt="rendu impossible">'
            note = "" if page["png"] and page["pdf"] else ' <span class="ko">(rendu partiel)</span>'
            figures.append(
                "    <figure>{v}<figcaption><b>{l}</b>{liens}{note}</figcaption></figure>".format(
                    v=vignette, l=html.escape(page["label"]),
                    liens=" ".join(liens), note=note,
                )
            )
        sections.append(GABARIT_SECTION.format(num=html.escape(num), figures="\n".join(figures)))

    index = sortie / "index.html"
    index.write_text(
        GABARIT_INDEX.format(
            tour=html.escape(f"- tour {tour}" if tour else ""),
            nb_cmd=len(par_commandant),
            nb_pages=nb_pages,
            source=html.escape(str(source)),
            sections="\n".join(sections),
        ),
        encoding="utf-8",
    )
    return index


def main() -> int:
    p = argparse.ArgumentParser(
        description="Rend en PNG/PDF les rapports HTML des commandants, et batit une galerie."
    )
    p.add_argument("rapports", type=Path,
                   help="repertoire data/tour<N>/rapports produit par le moteur")
    p.add_argument("-o", "--out", type=Path, default=Path("capture-rapports"),
                   help="repertoire de sortie (defaut: ./capture-rapports)")
    p.add_argument("-c", "--commandant", action="append", default=None,
                   help="ne capturer que ce(s) numero(s) de commandant")
    p.add_argument("--chrome", default=None, help="chemin du binaire Chrome/Chromium")
    p.add_argument("--largeur", type=int, default=1400, help="largeur du viewport (defaut 1400)")
    p.add_argument("--hauteur", type=int, default=1000, help="hauteur du viewport (defaut 1000)")
    p.add_argument("--jobs", type=int, default=4, help="captures en parallele (defaut 4)")
    p.add_argument("--budget-ms", type=int, default=2000,
                   help="virtual-time-budget Chrome, en ms (defaut 2000)")
    p.add_argument("--pages", action="append", default=None,
                   help="ne capturer que ces noms de fichiers (ex: principal.htm)")
    p.add_argument("--archiver", action="store_true",
                   help="copier aussi le HTML source dans la sortie, sous html/. "
                        "data/tour<N>/ est gitignore et reecrit a chaque tour : sans "
                        "cela les liens 'source' de la galerie pointent vers du volatil.")
    args = p.parse_args()

    racine = args.rapports
    if not racine.is_dir():
        sys.exit(f"repertoire de rapports introuvable : {racine}")

    chrome = trouver_chrome(args.chrome)
    filtre_cmd = set(args.commandant) if args.commandant else None
    filtre_pages = set(args.pages) if args.pages else None

    commandants = lister_commandants(racine, filtre_cmd)
    if not commandants:
        sys.exit(
            f"aucun repertoire <num>tour<N> dans {racine}. "
            "Le moteur a-t-il deja produit un tour ?"
        )

    args.out.mkdir(parents=True, exist_ok=True)
    tour = commandants[0][1]

    archive = None
    if args.archiver:
        archive = args.out / "html"
        if archive.exists():
            shutil.rmtree(archive)
        archive.mkdir(parents=True)
        if (racine / "images").is_dir():
            shutil.copytree(racine / "images", archive / "images")
        for _num, _t, repertoire in commandants:
            shutil.copytree(repertoire, archive / repertoire.name)
        print(f"archive : {archive} (HTML source copie)")

    # Constitution de la liste de travail.
    travaux = []
    for num, _tour, repertoire in commandants:
        for fichier in sorted(repertoire.glob("*.htm"), key=lambda f: rang_page(f.name)):
            if filtre_pages and fichier.name not in filtre_pages:
                continue
            tige = fichier.stem
            if archive is not None:
                src_lien = f"html/{repertoire.name}/{fichier.name}"
            else:
                src_lien = os.path.relpath(fichier.resolve(), args.out.resolve())
            travaux.append({
                "num": num,
                "src_abs": fichier,
                "label": libelle_page(fichier.name, num),
                "png_abs": args.out / num / f"{tige}.png",
                "pdf_abs": args.out / num / f"{tige}.pdf",
                "png": f"{num}/{tige}.png",
                "pdf": f"{num}/{tige}.pdf",
                "src": src_lien,
            })

    if not travaux:
        sys.exit("aucune page .htm a capturer.")

    print(f"chrome   : {chrome}")
    print(f"source   : {racine}")
    print(f"sortie   : {args.out}")
    print(f"a rendre : {len(travaux)} page(s) sur {len(commandants)} commandant(s)")

    echecs = []

    def executer(t):
        ok_png, ok_pdf, err = capturer(
            chrome, t["src_abs"], t["png_abs"], t["pdf_abs"],
            args.largeur, args.hauteur, args.budget_ms,
        )
        t["png"] = t["png"] if ok_png else None
        t["pdf"] = t["pdf"] if ok_pdf else None
        if not (ok_png and ok_pdf):
            echecs.append(f"{t['num']}/{t['src_abs'].name} ({err or 'sortie vide'})")
        return t

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for i, t in enumerate(pool.map(executer, travaux), 1):
            marque = "ok" if (t["png"] and t["pdf"]) else "KO"
            print(f"  [{i}/{len(travaux)}] {marque}  {t['num']}/{t['src_abs'].name}")

    par_commandant: dict[str, list[dict]] = {}
    for t in travaux:
        par_commandant.setdefault(t["num"], []).append(t)

    index = construire_index(args.out, racine, tour, par_commandant)

    print()
    if echecs:
        print(f"{len(echecs)} page(s) en echec :")
        for e in echecs:
            print(f"  - {e}")
    print(f"galerie : {index.resolve().as_uri()}")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
