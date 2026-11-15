&& =====================================================================
&& Numérisation - Canon CanoScan LiDE 120, sans pilote du fabricant
&& ---------------------------------------------------------------------
&& Application Lexis+ qui pilote directement le scanner par USB (paquet
&& usb, libusb-1.0) : amorçage de la puce GL124, étalonnage, aperçu,
&& choix de la zone à la souris, numérisation de 75 à 2400 dpi en
&& couleur, gris ou trait (8 / 16 bits), retouches, enregistrement en
&& PDF (une ou plusieurs pages), JPEG, PNG ou TIFF, boutons du scanner.
&&
&&   wdlexisrt principal.prg                 interface graphique
&&   wdlexisrt principal.prg --simulation    sans scanner (LiDE 120 simulé)
&&   wdlexisrt principal.prg --essai [--usb] [--dossier d]
&&                                           essai sans interface : aperçu
&&                                           et numérisation à 300 dpi
&&   --trace fichier.txt                     journal de tous les transferts USB
&&   --comparer mode res prof x y l h sortie [zero]
&&                                           journal des écritures d'une numérisation
&&                                           simulée (voir verification/LISEZMOI.md)
&&
&& Fichiers :
&&   lide120.prg     description du modèle (tables reprises de SANE)
&&   registres.prg   jeux de registres, opérations sur les bits
&&   transport.prg   protocole USB du GL124
&&   session.prg     géométrie d'une numérisation, pentes du moteur
&&   gl124.prg       commande de la puce (portage de gl124.cpp)
&&   etalonnage.prg  diodes, noir, blanc, coefficients d'ombrage
&&   numeriser.prg   interface du pilote : ouvrir, numériser, boutons
&&   simulateur.prg  LiDE 120 simulé pour les essais
&& =====================================================================

NL = car(10)
SIMULATION = faux
ESSAI = faux
COMPARER = nul
FORCER_USB = faux
TRACE = nul
DOSSIER = fichier.joindre(fichier.dossierperso(), "Numérisations")
locale i = 1
tantque i <= #systeme.args
  locale a = systeme.args[i]
  faire cas
  cas a = "--simulation"
    SIMULATION = vrai
  cas a = "--essai"
    ESSAI = vrai
  cas a = "--usb"
    FORCER_USB = vrai
  cas a = "--comparer" et i + 8 <= #systeme.args
    COMPARER = {}
    pour k = 1 a 9
      inserer(COMPARER, systeme.args[i + k])
    suivant
    i += 8
  cas a = "--trace" et i < #systeme.args
    i += 1
    TRACE = fichier.absolu(systeme.args[i])
  cas a = "--dossier" et i < #systeme.args
    i += 1
    DOSSIER = fichier.absolu(systeme.args[i])
  fincas
  i += 1
fintantque
fichier.creerdossier(DOSSIER)

si ESSAI
  essayer
    ESSAI_SANS_INTERFACE()
  capturer e
    ? "Échec : " + e
    systeme.quitter(1)
  finessayer
  systeme.quitter(0)
finsi
si COMPARER <> nul
  COMPARER_SANS_INTERFACE(COMPARER)
  systeme.quitter(0)
finsi

ui = paquet("interface")
TEMP = fichier.joindre(fichier.dossiertemp(), "lide120_lexis")
fichier.creerdossier(TEMP)
OCCUPE = faux
APERCU = nul                  && trame de l'aperçu (75 dpi, vitre entière)
APERCU_RES = 75
DERNIERE = nul                && dernière numérisation
PAGES = {}                    && document en cours (PDF multipage)
ECHELLE = 3                   && unités de la toile par millimètre
ZONE = {x = 0, y = 0, largeur = 210, hauteur = 297}
ID_ZONE = nul
ID_FOND = nul
MAJ_ZONE = faux
BOUTONS_AVANT = nul
FORMATS = {{"Personnalisée", 0, 0}, {"Vitre entière (216 × 297 mm)", 216, 297}, {"A4 (210 × 297 mm)", 210, 297}, ;
           {"A5 (148 × 210 mm)", 148, 210}, {"Lettre US (216 × 279 mm)", 216, 279}, {"Photo 10 × 15 cm", 100, 150}, ;
           {"Photo 13 × 18 cm", 130, 180}, {"Carte de visite (85 × 55 mm)", 85, 55}}
RESOLUTIONS = {75, 100, 150, 300, 600, 1200, 2400}

&& --- fenêtre ---------------------------------------------------------------
fen = ui.fenetre{titre = "Numérisation - Canon LiDE 120 (Lexis+)", largeur = 1320, hauteur = 960, disposition = "bordure"}

haut = fen:ajouter(ui.rangee())
haut.ancrage = "haut"
haut.marge = 8
haut.espacement = 8
csource = haut:ajouter(ui.combo("Canon LiDE 120 (USB)", "LiDE 120 simulé"))
csource.largeurfixe = 210
csource:selectionner(sisinon(SIMULATION, 2, 1))
bconnecter = haut:ajouter(ui.bouton("Connecter"))
bconnecter.surclic = @CONNECTER
lsource = haut:ajouter(ui.etiquette("Aucun scanner."))
lsource.poids = 1
bapercu = haut:ajouter(ui.bouton("Aperçu"))
bapercu.infobulle = "Numérise toute la vitre à 75 dpi pour choisir la zone"
bapercu.surclic = @ACTION_APERCU
bnum = haut:ajouter(ui.bouton("Numériser"))
bnum.infobulle = "Numérise la zone choisie avec les réglages"
bnum.surclic = @ACTION_NUMERISER
barret = haut:ajouter(ui.bouton("Arrêter"))
barret.surclic = @ACTION_ARRETER

bas = fen:ajouter(ui.rangee())
bas.ancrage = "bas"
bas.marge = 6
bas.espacement = 8
etat = bas:ajouter(ui.etiquette("Prêt."))
etat.poids = 1
ldossier = bas:ajouter(ui.etiquette(DOSSIER))
ldossier.couleur = "#6C757D"
bdossier = bas:ajouter(ui.bouton("Dossier…"))
bdossier.infobulle = "Dossier où sont enregistrées les numérisations"
bdossier.surclic = @CHOISIR_DOSSIER
bouvrir = bas:ajouter(ui.bouton("Ouvrir"))
bouvrir.surclic = @OUVRIR_DOSSIER
jauge = bas:ajouter(ui.jauge())
jauge.largeurfixe = 260
jauge.max = 1
jauge.num = 0

&& --- réglages (à gauche) -----------------------------------------------------
gauche = fen:ajouter(ui.colonne())
gauche.ancrage = "gauche"
gauche.largeurfixe = 330
gauche.marge = 8
gauche.espacement = 6

cnum = gauche:ajouter(ui.cadre("Numérisation"))
cnum.espacement = 4
cmode = CHAMP(cnum, "Mode", ui.combo("Couleur", "Gris", "Trait (noir et blanc)"))
cmode:selectionner(1)
cres = CHAMP(cnum, "Résolution", ui.combo())
pour chaque r dans RESOLUTIONS
  cres:ajouter(chaine(r))
suivant
cres:selectionner(4)
cprof = CHAMP(cnum, "Profondeur", ui.combo("8 bits", "16 bits"))
cprof:selectionner(1)

czone = gauche:ajouter(ui.cadre("Zone (mm)"))
czone.espacement = 4
cformat = czone:ajouter(ui.combo())
pour chaque f dans FORMATS
  cformat:ajouter(f[1])
suivant
cformat:selectionner(3)
cformat.surselection = @FORMAT_CHOISI
rz1 = czone:ajouter(ui.rangee())
rz1.espacement = 4
rz1.hauteurfixe = 44
sx = PETIT_CHAMP(rz1, "Gauche", "0")
sy = PETIT_CHAMP(rz1, "Haut", "0")
rz2 = czone:ajouter(ui.rangee())
rz2.espacement = 4
rz2.hauteurfixe = 44
sl = PETIT_CHAMP(rz2, "Largeur", "210")
sh = PETIT_CHAMP(rz2, "Hauteur", "297")
pour chaque s dans {sx, sy, sl, sh}
  s.survalidation = @ZONE_SAISIE
  s.surfinfocus = @ZONE_SAISIE
suivant
lzone = czone:ajouter(ui.etiquette(""))
lzone.couleur = "#6C757D"

cret = gauche:ajouter(ui.cadre("Retouches"))
cret.espacement = 4
cluminosite = CHAMP(cret, "Luminosité", ui.curseur())
cluminosite.min = -50
cluminosite.max = 50
cluminosite.num = 0
ccontraste = CHAMP(cret, "Contraste", ui.curseur())
ccontraste.min = -50
ccontraste.max = 50
ccontraste.num = 0
crotation = CHAMP(cret, "Rotation", ui.combo("Aucune", "90° à droite", "180°", "90° à gauche"))
crotation:selectionner(1)

csortie = gauche:ajouter(ui.cadre("Enregistrement"))
csortie.espacement = 4
cfichier = CHAMP(csortie, "Format", ui.combo("PDF", "JPEG", "PNG", "TIFF"))
cfichier:selectionner(1)
squalite = DERNIERE_RANGEE:ajouter(ui.saisie("88"))
squalite.largeurfixe = 44
squalite.infobulle = "Qualité JPEG (10 à 100), aussi pour les PDF"
rmulti = csortie:ajouter(ui.rangee())
rmulti.espacement = 4
rmulti.hauteurfixe = 44
cmulti = rmulti:ajouter(ui.cases("Plusieurs pages"))
cmulti.infobulle = "Chaque numérisation ajoute une page ; « Enregistrer le document » écrit le PDF"
cmulti.poids = 1
lpages = rmulti:ajouter(ui.etiquette("0 page"))
rpages = csortie:ajouter(ui.rangee())
rpages.espacement = 4
rpages.hauteurfixe = 44
bpdf = rpages:ajouter(ui.bouton("Enregistrer le document"))
bpdf.surclic = @ENREGISTRER_DOCUMENT
bpdf.poids = 1
bvider = rpages:ajouter(ui.bouton("Vider"))
bvider.surclic = @VIDER_DOCUMENT


&& --- centre : aperçu, résultat, journal, diagnostic ----------------------------
onglets = fen:ajouter(ui.onglets())
onglets.ancrage = "centre"
papercu = onglets:ajouterpage("Aperçu")
aide = papercu:ajouter(ui.etiquette("Faites un aperçu, puis déplacez ou redimensionnez le cadre bleu pour choisir la zone."))
aide.couleur = "#6C757D"
vue = papercu:ajouter(ui.toile())
vue.poids = 1
vue.surchangement = @ZONE_DEPLACEE
presultat = onglets:ajouterpage("Dernière numérisation")
lresultat = presultat:ajouter(ui.etiquette("Aucune numérisation."))
vresultat = presultat:ajouter(ui.toile{mode = "lecture"})
vresultat.poids = 1
pjournal = onglets:ajouterpage("Journal")
journal = pjournal:ajouter(ui.liste())
journal.poids = 1
pdiag = onglets:ajouterpage("Diagnostic")
rdiag = pdiag:ajouter(ui.rangee())
rdiag.espacement = 6
rdiag.marge = 4
bdiag1 = rdiag:ajouter(ui.bouton("État du scanner"))
bdiag1.surclic = @DIAG_ETAT
bdiag2 = rdiag:ajouter(ui.bouton("Registres"))
bdiag2.surclic = @DIAG_REGISTRES
bdiag3 = rdiag:ajouter(ui.bouton("Refaire l'étalonnage"))
bdiag3.infobulle = "Oublie les étalonnages mémorisés : le prochain passage étalonne à nouveau"
bdiag3.surclic = @DIAG_ETALONNAGE
bdiag4 = rdiag:ajouter(ui.bouton("Ramener la tête"))
bdiag4.surclic = @DIAG_TETE
bdiag5 = rdiag:ajouter(ui.bouton("Tracer l'USB…"))
bdiag5.infobulle = "Enregistre chaque transfert USB dans un fichier (comparaison avec une capture du pilote Canon ou de SANE)"
bdiag5.surclic = @DIAG_TRACE
diag = pdiag:ajouter(ui.markdown("Connectez le scanner pour afficher son état."))
diag.poids = 1

DESSINER_VITRE()
FORMAT_CHOISI()
ui.minuterie(300, @SURVEILLER_BOUTONS)
ui.minuterie(50, @DEMARRAGE, faux)
ui.executer()
SCANNER_FERMER()

&& =============================================================================

fonction CHAMP(conteneur, t, controle)
  locale r = conteneur:ajouter(ui.rangee())
  r.espacement = 6
  r.hauteurfixe = 44
  locale e = r:ajouter(ui.etiquette(t))
  e.couleur = "#495057"
  e.largeurfixe = 92
  locale c = r:ajouter(controle)
  c.poids = 1
  globale DERNIERE_RANGEE
  DERNIERE_RANGEE = r
retourner c

fonction PETIT_CHAMP(rangee, t, v)
  locale e = rangee:ajouter(ui.etiquette(t))
  e.couleur = "#495057"
  e.largeurfixe = 62
  locale c = rangee:ajouter(ui.saisie(v))
  c.largeurfixe = 70
retourner c

procedure NOTER(msg)
  pour chaque ligne dans decouper(chaine(msg), NL)
    journal:ajouter(heure() + "  " + ligne)
  suivant
  journal:selectionner(journal:nombre())
retourner

procedure SUIVI(ev)
  si ev.genre = "journal"
    NOTER(ev.texte)
  sinon
    etat.libelle = ev.texte + "…"
    jauge.num = ev.fraction
  finsi
retourner

procedure DEMARRAGE(ev)
  CONNECTER()
retourner

procedure ACTIVER(actif)
  pour chaque b dans {bapercu, bnum, bconnecter, bdiag1, bdiag2, bdiag4}
    b.actif = actif
  suivant
retourner

&& --- connexion ----------------------------------------------------------------

procedure CONNECTER(ev)
  globale OCCUPE, SIMULATION
  si OCCUPE
    retourner
  finsi
  OCCUPE = vrai
  ACTIVER(faux)
  SCANNER_FERMER()
  SIMULATION = csource:selection() = 2
  etat.libelle = "Connexion…"
  essayer
    SCANNER_OUVRIR({simulation = SIMULATION, trace = TRACE, suivi = @SUIVI})
    lsource.libelle = DEV.description
    etat.libelle = "Prêt."
  capturer e
    NOTER("connexion : " + e)
    lsource.libelle = "Non connecté : " + e
    etat.libelle = "Scanner non connecté."
    si non SIMULATION
      ui.alerte(e + NL + NL + "Vérifiez le câble USB et les droits d'accès (voir LISEZMOI.md), " + ;
                "ou choisissez « LiDE 120 simulé » pour essayer l'application sans scanner.", "attention")
    finsi
  finessayer
  jauge.num = 0
  ACTIVER(vrai)
  OCCUPE = faux
retourner

&& --- toile : vitre, aperçu et zone ---------------------------------------------

procedure DESSINER_VITRE()
  globale ID_ZONE, ID_FOND
  vue:vider()
  locale l = 216 * ECHELLE
  locale h = 300 * ECHELLE
  vue:dimensions(l, h)
  vue:fond("#F8F9FA")
  si APERCU <> nul
    locale chemin = fichier.joindre(TEMP, "apercu.png")
    ID_FOND = vue:ajouter{genre = "image", nom = "apercu", x = 0, y = 0, ;
                          largeur = APERCU:largeur() * 25.4 / APERCU_RES * ECHELLE, ;
                          hauteur = APERCU:hauteur() * 25.4 / APERCU_RES * ECHELLE, ;
                          image = chemin, verrouille = vrai}
  sinon
    ID_FOND = vue:ajouter{genre = "rectangle", nom = "vitre", x = 0, y = 0, largeur = l, hauteur = h, ;
                          remplissage = "#F1F3F5", contour = "#ADB5BD", epaisseur = 1, verrouille = vrai}
    vue:ajouter{genre = "texte", x = l / 2 - 150, y = h / 2 - 20, largeur = 300, hauteur = 40, ;
                texte = "Vitre du scanner : faites un aperçu", taille = 16, alignement = "centre", ;
                remplissage = "#868E96", verrouille = vrai}
  finsi
  ID_ZONE = vue:ajouter{genre = "rectangle", nom = "zone", x = ZONE.x * ECHELLE, y = ZONE.y * ECHELLE, ;
                        largeur = ZONE.largeur * ECHELLE, hauteur = ZONE.hauteur * ECHELLE, ;
                        remplissage = "#228BE622", contour = "#1C7ED6", epaisseur = 2}
  vue:ajuster()
retourner

procedure BORNER_ZONE()
  ZONE.largeur = max(5, min(ZONE.largeur, 216))
  ZONE.hauteur = max(5, min(ZONE.hauteur, 300))
  ZONE.x = max(0, min(ZONE.x, 216 - ZONE.largeur))
  ZONE.y = max(0, min(ZONE.y, 300 - ZONE.hauteur))
retourner

procedure AFFICHER_ZONE()
  globale MAJ_ZONE
  MAJ_ZONE = vrai
  sx.valeur = chaine(arrondi(ZONE.x, 1))
  sy.valeur = chaine(arrondi(ZONE.y, 1))
  sl.valeur = chaine(arrondi(ZONE.largeur, 1))
  sh.valeur = chaine(arrondi(ZONE.hauteur, 1))
  MAJ_ZONE = faux
  locale r = RESOLUTION_CHOISIE()
  locale px = entier(ZONE.largeur * r / 25.4)
  locale py = entier(ZONE.hauteur * r / 25.4)
  locale canaux = sisinon(cmode:selection() = 1, 3, 1)
  locale octets = px * py * canaux * sisinon(cprof:selection() = 2 et cmode:selection() <> 3, 2, 1)
  lzone.libelle = px + " × " + py + " pixels à " + r + " dpi (" + arrondi(octets / 1048576, 1) + " Mo)"
retourner

procedure ZONE_VERS_TOILE()
  si ID_ZONE <> nul
    vue:modifier(ID_ZONE, {x = ZONE.x * ECHELLE, y = ZONE.y * ECHELLE, ;
                           largeur = ZONE.largeur * ECHELLE, hauteur = ZONE.hauteur * ECHELLE})
  finsi
retourner

procedure ZONE_DEPLACEE(ev)
  si ID_ZONE = nul
    retourner
  finsi
  locale f = vue:forme(ID_ZONE)
  si f = nul
    && la zone a été supprimée (touche Suppr) : on la recrée
    DESSINER_VITRE()
    retourner
  finsi
  ZONE.x = f.x / ECHELLE
  ZONE.y = f.y / ECHELLE
  ZONE.largeur = f.largeur / ECHELLE
  ZONE.hauteur = f.hauteur / ECHELLE
  locale avant = copier(ZONE)
  BORNER_ZONE()
  si avant.x <> ZONE.x ou avant.y <> ZONE.y ou avant.largeur <> ZONE.largeur ou avant.hauteur <> ZONE.hauteur
    ZONE_VERS_TOILE()
  finsi
  cformat:selectionner(1)
  AFFICHER_ZONE()
retourner

procedure ZONE_SAISIE(ev)
  si MAJ_ZONE
    retourner
  finsi
  ZONE.x = valeur(sx.valeur)
  ZONE.y = valeur(sy.valeur)
  ZONE.largeur = valeur(sl.valeur)
  ZONE.hauteur = valeur(sh.valeur)
  BORNER_ZONE()
  ZONE_VERS_TOILE()
  AFFICHER_ZONE()
retourner

procedure FORMAT_CHOISI(ev)
  locale f = FORMATS[max(1, cformat:selection())]
  si f[2] > 0
    ZONE.largeur = f[2]
    ZONE.hauteur = f[3]
    BORNER_ZONE()
    ZONE_VERS_TOILE()
  finsi
  AFFICHER_ZONE()
retourner

fonction RESOLUTION_CHOISIE()
retourner RESOLUTIONS[max(1, cres:selection())]

&& --- actions -------------------------------------------------------------------

fonction OPTIONS_NUMERISATION()
  locale modes = {"couleur", "gris", "trait"}
  locale rot = {0, 90, 180, 270}
  locale o = {}
  o.resolution = RESOLUTION_CHOISIE()
  o.mode = modes[cmode:selection()]
  o.profondeur = sisinon(cprof:selection() = 2, 16, 8)
  o.x = ZONE.x
  o.y = ZONE.y
  o.largeur = ZONE.largeur
  o.hauteur = ZONE.hauteur
  o.luminosite = cluminosite.num
  o.contraste = ccontraste.num
  o.rotation = rot[crotation:selection()]
retourner o

fonction PRET()
  globale OCCUPE
  si OCCUPE
    retourner faux
  finsi
  si DEV = nul
    ui.alerte("Aucun scanner connecté.", "info")
    retourner faux
  finsi
retourner vrai

procedure ACTION_APERCU(ev)
  globale OCCUPE, APERCU
  si non PRET()
    retourner
  finsi
  OCCUPE = vrai
  ACTIVER(faux)
  essayer
    locale img = NUMERISER({resolution = APERCU_RES, mode = "couleur", x = 0, y = 0, largeur = 216, hauteur = 300})
    APERCU = img
    img:enregistrer(fichier.joindre(TEMP, "apercu.png"))
    DESSINER_VITRE()
    onglets.valeur = 1
    etat.libelle = "Aperçu prêt : choisissez la zone."
  capturer e
    ERREUR_NUMERISATION(e)
  finessayer
  jauge.num = 0
  ACTIVER(vrai)
  OCCUPE = faux
retourner

procedure ACTION_NUMERISER(ev)
  globale OCCUPE, DERNIERE
  si non PRET()
    retourner
  finsi
  OCCUPE = vrai
  ACTIVER(faux)
  locale o = OPTIONS_NUMERISATION()
  essayer
    locale img = FINIR_IMAGE(NUMERISER(o), o)
    DERNIERE = img
    locale vignette = img
    locale k = min(900 / img:largeur(), 700 / img:hauteur())
    si k < 1
      vignette = img:redimensionner(max(1, entier(img:largeur() * k)), max(1, entier(img:hauteur() * k)))
    finsi
    locale cv = fichier.joindre(TEMP, "derniere_" + entier(systeme.horloge() * 1000) + ".png")
    vignette:en8bits():enregistrer(cv)
    vresultat:vider()
    vresultat:dimensions(vignette:largeur(), vignette:hauteur())
    vresultat:ajouter{genre = "image", x = 0, y = 0, largeur = vignette:largeur(), hauteur = vignette:hauteur(), ;
                      image = cv, verrouille = vrai}
    vresultat:ajuster()
    locale info = img:largeur() + " × " + img:hauteur() + " pixels, " + o.resolution + " dpi, " + o.mode
    si (nombre(cmulti.valeur) ou 0) > 0
      inserer(PAGES, img)
      lpages.libelle = #PAGES + sisinon(#PAGES > 1, " pages", " page")
      lresultat.libelle = info + " - page " + #PAGES + " du document"
      NOTER("page " + #PAGES + " ajoutée au document")
    sinon
      locale chemin = ENREGISTRER_IMAGE(img)
      lresultat.libelle = info + " - " + chemin
    finsi
    onglets.valeur = 2
    etat.libelle = "Numérisation terminée."
  capturer e
    ERREUR_NUMERISATION(e)
  finessayer
  jauge.num = 0
  ACTIVER(vrai)
  OCCUPE = faux
retourner

procedure ERREUR_NUMERISATION(e)
  NOTER("erreur : " + e)
  etat.libelle = "Erreur : " + e
  si non ("interrompue" $ e)
    ui.alerte(e, "attention")
  finsi
retourner

procedure ACTION_ARRETER(ev)
  si OCCUPE
    SCANNER_ARRETER()
    etat.libelle = "Arrêt demandé…"
  finsi
retourner

fonction NOM_FICHIER(ext)
  locale base = "numerisation_" + systeme.date("%Y%m%d_%H%M%S")
  locale chemin = fichier.joindre(DOSSIER, base + "." + ext)
  locale n = 2
  tantque fichier.existe(chemin)
    chemin = fichier.joindre(DOSSIER, base + "_" + n + "." + ext)
    n += 1
  fintantque
retourner chemin

fonction ENREGISTRER_IMAGE(img)
  locale exts = {"pdf", "jpg", "png", "tif"}
  locale ext = exts[cfichier:selection()]
  locale chemin = NOM_FICHIER(ext)
  locale q = max(10, min(100, nombre(squalite.valeur) ou 88))
  locale n = img:enregistrer(chemin, {qualite = q})
  NOTER("enregistré : " + chemin + " (" + arrondi(n / 1024) + " Ko)")
retourner chemin

procedure ENREGISTRER_DOCUMENT(ev)
  globale PAGES
  si #PAGES = 0
    ui.alerte("Le document est vide : cochez « Document de plusieurs pages » puis numérisez.", "info")
    retourner
  finsi
  locale chemin = NOM_FICHIER("pdf")
  locale q = max(10, min(100, nombre(squalite.valeur) ou 88))
  locale n = trame.pdf(chemin, PAGES, {qualite = q})
  NOTER("document enregistré : " + chemin + " (" + #PAGES + " pages, " + arrondi(n / 1024) + " Ko)")
  lresultat.libelle = "Document de " + #PAGES + " pages : " + chemin
  PAGES = {}
  lpages.libelle = "0 page"
retourner

procedure VIDER_DOCUMENT(ev)
  globale PAGES
  PAGES = {}
  lpages.libelle = "0 page"
retourner

procedure CHOISIR_DOSSIER(ev)
  globale DOSSIER
  locale f = ui.enregistrerfichier{nom = "numerisation.pdf"}
  si f <> nul
    DOSSIER = fichier.dossier(f)
    ldossier.libelle = DOSSIER
  finsi
retourner

procedure OUVRIR_DOSSIER(ev)
  locale p = systeme.plateforme()
  faire cas
  cas p = "windows"
    systeme.executer("explorer \"" + DOSSIER + "\"")
  cas p = "macosx"
    systeme.executer("open \"" + DOSSIER + "\"")
  autrement
    systeme.executer("xdg-open \"" + DOSSIER + "\" >/dev/null 2>&1 &")
  fincas
retourner

&& --- boutons du scanner ----------------------------------------------------------
&& Numériser et Fichier : numérisation ; Copier : aperçu ;
&& Courriel : numérisation ajoutée au document puis PDF enregistré.
procedure SURVEILLER_BOUTONS(ev)
  globale BOUTONS_AVANT
  si OCCUPE ou DEV = nul
    retourner
  finsi
  locale b
  essayer
    b = SCANNER_BOUTONS()
  capturer e
    retourner
  finessayer
  locale avant = BOUTONS_AVANT ou {}
  BOUTONS_AVANT = b
  si b.numeriser et non avant.numeriser
    NOTER("bouton Numériser")
    ACTION_NUMERISER()
  sinonsi b.fichier et non avant.fichier
    NOTER("bouton Fichier")
    ACTION_NUMERISER()
  sinonsi b.copier et non avant.copier
    NOTER("bouton Copier : aperçu")
    ACTION_APERCU()
  sinonsi b.courriel et non avant.courriel
    NOTER("bouton Courriel : document PDF")
    cmulti.valeur = 1
    ACTION_NUMERISER()
    ENREGISTRER_DOCUMENT()
  finsi
retourner

&& --- diagnostic -------------------------------------------------------------------

procedure DIAG_ETAT(ev)
  si non PRET()
    retourner
  finsi
  locale s = GL_ETAT()
  locale b = SCANNER_BOUTONS()
  locale md = "### " + DEV.description + NL + NL
  md = md + "- Tête en position de repos : **" + OUI(s.a_la_base) + "**" + NL
  md = md + "- Position estimée : " + (DEV.tete ou "inconnue") + " pas" + NL
  md = md + "- Moteur en marche : " + OUI(s.moteur) + NL
  md = md + "- Lampe : " + OUI(s.lampe) + NL
  md = md + "- Tampon vide : " + OUI(s.tampon_vide) + NL
  md = md + "- Registre d'état 0x101 : `" + HEX2(s.brut) + "`" + NL
  md = md + "- Boutons appuyés : " + BOUTONS_TEXTE(b) + NL
  md = md + "- Mode USB : " + DEV.usb_mode + NL
  md = md + "- Étalonnages mémorisés : " + nbelements(DEV.cache) + NL
  locale e = CAPTEUR_EXPO(CAPTEUR(300, 3))
  md = md + "- Expositions des diodes (300 dpi) : R " + e.r + ", G " + e.g + ", B " + e.b + NL
  si non DEV.tr.simulation
    locale st = DEV.tr.p:statistiques()
    md = md + "- Transferts USB : " + st.transferts + " (" + arrondi(st.octetslus / 1048576, 1) + " Mo lus)" + NL
  finsi
  diag.valeur = md
retourner

fonction OUI(v)
retourner sisinon(v, "oui", "non")

fonction BOUTONS_TEXTE(b)
  locale l = {}
  pour chaque k, v dans b
    si v
      inserer(l, minuscule(k))
    finsi
  suivant
  si #l = 0
    retourner "aucun"
  finsi
retourner joindre(l, ", ")

procedure DIAG_REGISTRES(ev)
  si non PRET()
    retourner
  finsi
  locale md = "### Registres programmés (jeu courant)" + NL + NL + "```" + NL
  locale ligne = {}
  pour chaque a dans DEV.reg.adresses
    inserer(ligne, droite(HEX4(a), 3) + ":" + droite(HEX2(DEV.reg.val[a]), 2))
    si #ligne = 8
      md = md + joindre(ligne, "  ") + NL
      ligne = {}
    finsi
  suivant
  md = md + joindre(ligne, "  ") + NL + "```" + NL
  si DEV.session <> nul
    locale s = DEV.session
    md = md + NL + "Dernière session : " + s.params.xres + " dpi, " + s.output_pixels + " pixels × " + ;
         s.params.lines + " lignes, pixels " + s.pixel_startx + " à " + s.pixel_endx + ", départ " + s.params.starty + " pas." + NL
  finsi
  diag.valeur = md
retourner

procedure DIAG_ETALONNAGE(ev)
  si DEV <> nul
    CAL_OUBLIER()
    NOTER("étalonnages oubliés : le prochain passage étalonne à nouveau")
  finsi
retourner

procedure DIAG_TETE(ev)
  globale OCCUPE
  si non PRET()
    retourner
  finsi
  OCCUPE = vrai
  essayer
    GL_RETOUR_BASE(vrai)
    NOTER("tête en position de repos")
  capturer e
    NOTER("retour de la tête : " + e)
  finessayer
  OCCUPE = faux
retourner

procedure DIAG_TRACE(ev)
  si DEV = nul ou DEV.tr.simulation
    ui.alerte("La trace USB concerne le scanner réel.", "info")
    retourner
  finsi
  locale f = ui.enregistrerfichier{nom = "trace_usb.txt"}
  si f <> nul
    DEV.tr.p:tracer(f)
    NOTER("trace USB : " + f)
  finsi
retourner

&& --- essai sans interface ----------------------------------------------------------

procedure SUIVI_CONSOLE(ev)
  si ev.genre = "journal"
    ? "  " + ev.texte
  finsi
retourner

procedure ESSAI_SANS_INTERFACE()
  locale sim = non FORCER_USB
  ? "Essai du pilote LiDE 120 en Lexis+ (" + sisinon(sim, "simulation", "scanner USB") + ")"
  SCANNER_OUVRIR({simulation = sim, trace = TRACE, suivi = @SUIVI_CONSOLE})
  locale t0 = systeme.horloge()
  locale a = NUMERISER({resolution = 75, mode = "couleur", x = 0, y = 0, largeur = 216, hauteur = 300})
  locale f1 = fichier.joindre(DOSSIER, "essai_apercu_75dpi.png")
  a:enregistrer(f1)
  ? "aperçu : " + a:largeur() + " × " + a:hauteur() + " → " + f1 + " (" + arrondi(systeme.horloge() - t0, 1) + " s)"
  t0 = systeme.horloge()
  locale o = {resolution = 300, mode = "couleur", x = 20, y = 30, largeur = 100, hauteur = 70}
  locale b = FINIR_IMAGE(NUMERISER(o), o)
  locale f2 = fichier.joindre(DOSSIER, "essai_300dpi.jpg")
  b:enregistrer(f2, {qualite = 90})
  ? "300 dpi : " + b:largeur() + " × " + b:hauteur() + " → " + f2 + " (" + arrondi(systeme.horloge() - t0, 1) + " s)"
  locale g = NUMERISER({resolution = 150, mode = "gris", x = 0, y = 200, largeur = 216, hauteur = 80})
  locale f3 = fichier.joindre(DOSSIER, "essai_gris_150dpi.pdf")
  trame.pdf(f3, {g, b})
  ? "gris 150 dpi + couleur : PDF de 2 pages → " + f3
  ? "boutons : " + BOUTONS_TEXTE(SCANNER_BOUTONS())
  SCANNER_FERMER()
retourner

&& Journal des écritures (registres, frontal, mémoire) d'une numérisation
&& simulée, au format du pilote SANE instrumenté (verification/).
procedure COMPARER_SANS_INTERFACE(a)
  SCANNER_OUVRIR({simulation = vrai, journal = vrai, donnees_nulles = a[9] = "zero"})
  locale img = NUMERISER({resolution = nombre(a[2]), mode = sisinon(a[1] = "Color", "couleur", "gris"), ;
                          profondeur = nombre(a[3]), x = nombre(a[4]), y = nombre(a[5]), ;
                          largeur = nombre(a[6]), hauteur = nombre(a[7])})
  fichier.ecrirelignes(a[8], DEV.journal_ecritures)
  ? "Lexis+ : " + img:largeur() + " × " + img:hauteur() + ", " + #DEV.journal_ecritures + " écritures → " + a[8]
retourner
