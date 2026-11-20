&& =====================================================================
&& numeriser.prg - interface du pilote pour l'application
&& ---------------------------------------------------------------------
&&   SCANNER_OUVRIR({simulation=, trace=, suivi=@proc})  ouvre et amorce
&&   NUMERISER({resolution=, mode=, profondeur=, x=, y=, largeur=,
&&              hauteur=, filtre=})                      → trame
&&   SCANNER_BOUTONS()                                   état des boutons
&&   SCANNER_ARRETER()                                   demande d'arrêt
&&   SCANNER_FERMER()
&& Les dimensions sont en millimètres depuis le coin de la vitre (repère
&& du scanner : x le long de la barre CIS, y dans le sens du chariot).
&& =====================================================================

procedure JOURNAL(m)
  globale DEV
  si DEV <> nul et DEV.suivi <> nul
    appeler(DEV.suivi, {genre = "journal", texte = m})
  finsi
retourner

procedure ETAPE(m, fraction)
  globale DEV
  si DEV <> nul et DEV.suivi <> nul
    appeler(DEV.suivi, {genre = "etape", texte = m, fraction = fraction})
  finsi
retourner

procedure VERIFIER_ARRET()
  globale ARRET_SCANNER
  si ARRET_SCANNER
    ARRET_SCANNER = faux
    erreur "numérisation interrompue"
  finsi
retourner

procedure SCANNER_ARRETER()
  globale ARRET_SCANNER
  ARRET_SCANNER = vrai
retourner

fonction SCANNER_OUVRIR(o)
  globale DEV, ARRET_SCANNER
  o = o ou {}
  ARRET_SCANNER = faux
  DEV = {}
  DEV.suivi = o.suivi
  DEV.modele = LIDE120_MODELE()
  DEV.capteurs = LIDE120_CAPTEURS()
  DEV.moteur = LIDE120_MOTEUR()
  DEV.frontal_initial = LIDE120_FRONTAL()
  DEV.frontal = copier(DEV.frontal_initial)
  DEV.expositions = {}
  DEV.cache = {}
  DEV.expiration = o.expiration ou 60
  DEV.tete = nul
  DEV.initialise = faux
  DEV.parking = faux
  DEV.reglages = {xres = 75, yres = 75, color_filter = "rouge"}
  si o.journal
    DEV.journal_ecritures = {}
  finsi
  si o.simulation
    DEV.tr = T_SIMULATION(SIM_NOUVEAU())
    DEV.tr.sim.donnees_nulles = o.donnees_nulles
    DEV.description = "LiDE 120 simulé"
  sinon
    si non usb.disponible()
      erreur usb.erreur()
    finsi
    locale p = usb.ouvrir(DEV.modele.vendeur, DEV.modele.produit)
    si p = nul
      DEV = nul
      erreur "Canon LiDE 120 (USB 04a9:190e) introuvable : est-il branché ?"
    finsi
    si o.trace <> nul
      p:tracer(o.trace)
    finsi
    DEV.tr = T_USB(p)
    locale d = p:descripteur()
    DEV.description = (d.fabricant ou "Canon") + " " + (d.nom ou "LiDE 120") + " (bus " + d.bus + ", adresse " + d.adresse + ", USB " + d.vitesse + ")"
  finsi
  JOURNAL("ouvert : " + DEV.description)
  GL_INITIALISER()
  si DEV.version_puce <> nul
    JOURNAL("version de la puce : " + HEX2(DEV.version_puce))
  finsi
retourner DEV

procedure SCANNER_FERMER()
  globale DEV
  si DEV = nul
    retourner
  finsi
  essayer
    si non DEV.tr.simulation
      DEV.tr.p:fermer()
    finsi
  capturer e
  finessayer
  DEV = nul
retourner

fonction SCANNER_BOUTONS()
retourner LIDE120_BOUTONS(GL_LIRE_REG(0x31))

fonction PLUS_PROCHE(liste, v)
  locale meilleur = liste[1]
  pour chaque x dans liste
    si abs(x - v) < abs(meilleur - v)
      meilleur = x
    finsi
  suivant
retourner meilleur

&& calculate_scan_settings + calculate_scan_session
fonction REGLAGES(o)
  globale DEV
  locale m = DEV.modele
  locale g = {}
  g.xres = PLUS_PROCHE(m.resolutions_x, o.resolution ou 300)
  g.yres = PLUS_PROCHE(m.resolutions_y, o.resolution ou 300)
  g.mode = o.mode ou "couleur"
  g.channels = sisinon(g.mode = "couleur", 3, 1)
  g.depth = sisinon((o.profondeur ou 8) > 8 et g.mode <> "trait", 16, 8)
  && Gris et trait : une seule diode (verte par défaut). SANE n'offre pas le
  && « gris vrai » (addition des trois diodes, LEDADD) sur le GL124 : non pris
  && en charge par ce circuit selon genesys.cpp ; on fait de même.
  g.color_filter = o.filtre ou "vert"
  si g.color_filter = "aucun"
    g.color_filter = "vert"
  finsi
  si g.channels = 3
    g.color_filter = "aucun"
  finsi
  g.tl_x = max(0, o.x ou 0)
  g.tl_y = max(0, o.y ou 0)
  locale br_x = min(m.x_size, g.tl_x + (o.largeur ou m.x_size))
  locale br_y = min(m.y_size, g.tl_y + (o.hauteur ou 297))
  g.lines = entier((br_y - g.tl_y) * g.yres / m.mm_par_pouce)
  locale c = CAPTEUR(g.xres, g.channels)
  g.pixels = AJUSTER_PIXELS(entier((br_x - g.tl_x) * g.xres / m.mm_par_pouce), c, g.xres, g.yres, vrai)
  g.requested_pixels = g.pixels
  si g.lines < 1 ou g.pixels < 4
    erreur "zone de numérisation trop petite"
  finsi
retourner g

fonction SESSION_NUMERISATION(g, c)
  globale DEV
  locale m = DEV.modele
  locale move_dpi = DIVE(m.base_ydpi, 4)
  locale move = (m.y_offset + g.tl_y) * move_dpi / m.mm_par_pouce
  locale start = m.x_offset + g.tl_x
  start = start / DIVE(c.full_resolution, c.optical_resolution)
  start = start * g.xres / m.mm_par_pouce
  locale p = PARAMS(g.xres, g.yres, entier(start), entier(move), g.pixels, g.lines, g.depth, g.channels, ;
                    sisinon(g.channels = 3, "couleur", "gris"), g.color_filter, {})
  p.requested_pixels = g.requested_pixels
retourner CALCULER_SESSION(p, c)

&& sanei_genesys_wait_for_home
procedure ATTENDRE_REPOS()
  globale DEV
  DEV.parking = faux
  GL_ETAT()
  GL_DORMIR(10)
  si GL_ETAT().a_la_base
    retourner
  finsi
  locale t0 = systeme.horloge()
  tantque non GL_ETAT().a_la_base
    GL_DORMIR(100)
    si systeme.horloge() - t0 > 200
      erreur "la tête n'a pas rejoint sa position de repos"
    finsi
  fintantque
retourner

&& genesys_start_scan + lecture des données (genesys_read_ordered_data)
fonction NUMERISER(o)
  globale DEV, ARRET_SCANNER
  si DEV = nul
    erreur "scanner non ouvert"
  finsi
  ARRET_SCANNER = faux
  locale g = REGLAGES(o)
  DEV.reglages = g
  locale c = CAPTEUR(g.xres, g.channels)
  locale t0 = systeme.horloge()
  ETAPE("Préparation", 0.01)
  si DEV.parking
    ATTENDRE_REPOS()
  finsi
  GL_RETOUR_BASE(vrai)
  GL_ENVOYER_GAMMA(c)
  locale s = SESSION_NUMERISATION(g, c)
  si o.etalonner ou non CAL_RESTAURER(c, s)
    CAL_ETALONNER(c)
    CAL_MEMORISER(c, s)
  sinon
    JOURNAL("étalonnage repris du cache (" + CAL_CLE(s) + ")")
  finsi
  GL_ATTENDRE_ARRET_MOTEUR()
  GL_RETOUR_BASE(vrai)
  && approche rapide de la zone (init_regs_for_scan)
  s = SESSION_NUMERISATION(g, c)
  si g.channels * g.yres >= 600 et s.params.starty > 700
    ETAPE("Approche de la zone", 0.22)
    GL_DEPLACER(s.params.starty - 500, faux)
    s.params.starty = 500
    s = CALCULER_SESSION(s.params, c)
  finsi
  GL_PROGRAMMER(c, DEV.reg, s)
  CAL_ENVOYER_OMBRAGE(c)
  GL_ECRIRE_REGS(DEV.reg)
  GL_DEBUT(c, DEV.reg, vrai)
  NOTER_ECRITURE("# start_scan")
  locale attendu = REGS_GET24(DEV.reg, 0x3d)
  tantque GL_PAS_AVANCE() < attendu
    GL_DORMIR(100)
    VERIFIER_ARRET()
  fintantque
  GL_ATTENDRE_DONNEES()
  tantque GL_MOTS_VALIDES() < 1
    GL_DORMIR(100)
    VERIFIER_ARRET()
  fintantque
  && lecture
  locale largeur = DIVE(s.output_line_bytes_raw, DIVE(g.depth, 8))
  locale img = trame.nouvelle(largeur, 0, g.channels, g.depth, {cis = g.channels = 3 et DEV.modele.is_cis, dpi = g.xres})
  locale total = s.output_line_bytes_raw * s.optical_line_count
  locale bloc = s.buffer_size_read
  bloc = bloc + bloc % 2
  locale lu = 0
  JOURNAL("lecture : " + largeur + " × " + g.lines + " pixels, " + g.xres + " dpi, " + g.depth + " bits, " + total + " octets")
  essayer
    tantque lu < total
      locale n = min(bloc, total - lu)
      img:ajouter(GL_LIRE_DONNEES(n))
      lu += n
      ETAPE("Numérisation", 0.25 + 0.73 * lu / total)
      VERIFIER_ARRET()
    fintantque
  capturer e
    essayer
      GL_ARRETER()
      GL_RETOUR_BASE(faux)
      DEV.parking = vrai
    capturer e2
    finessayer
    erreur e
  finessayer
  GL_ARRETER()
  GL_RETOUR_BASE(faux)
  DEV.parking = vrai
  si img:largeur() <> g.requested_pixels
    img = img:redimensionner(g.requested_pixels, img:hauteur())
  finsi
  ETAPE("Terminé", 1)
  JOURNAL("numérisation terminée en " + arrondi(systeme.horloge() - t0, 1) + " s")
retourner img

&& Retouches logicielles et mode trait
fonction FINIR_IMAGE(img, o)
  si (o.gamma ou 1) <> 1 ou (o.luminosite ou 0) <> 0 ou (o.contraste ou 0) <> 0
    img:niveaux({gamma = o.gamma ou 1, luminosite = o.luminosite ou 0, contraste = o.contraste ou 0})
  finsi
  si o.mode = "trait"
    img = img:trait(o.seuil ou 128)
  finsi
  si (o.rotation ou 0) <> 0
    img = img:pivoter(o.rotation)
  finsi
retourner img
