&& =====================================================================
&& simulateur.prg - LiDE 120 simulé (essais sans le matériel)
&& ---------------------------------------------------------------------
&& Répond aux mêmes requêtes USB que la puce GL124 : registres (avec le
&& 0x55 de lecture), en-têtes de lecture, mémoire AHB (pentes, gamma,
&& ombrage), registre d'état. Les lignes du capteur CIS sont calculées à
&& partir d'une mire posée sous la vitre (trame:capter) en tenant compte
&& des registres programmés par le pilote : zone (STRPIXEL, ENDPIXEL),
&& résolution (DPISET, SEGCNT), profondeur, filtre de couleur ou addition
&& des diodes, expositions, lampe, ombrage et gamma envoyés en mémoire.
&& Le simulateur vérifie ainsi la programmation du pilote de bout en bout ;
&& il ne remplace pas un essai sur le scanner réel.
&& =====================================================================

fonction SIM_NOUVEAU()
  locale s = {}
  s.regs = {}
  s.ahb = {}
  s.ahb_adr = nul
  s.a_lire = 0
  s.flux = ""
  s.en_cours = faux
  s.moteur = faux
  s.avance_finie = faux
  s.tete = 0.0                      && pouces depuis la position de repos
  s.mire = trame.mire(1654, 2339, 200)   && A4 à 200 dpi
  s.decalage = 8.0 / 25.4           && le document commence 8 mm sous le repos
  s.regs[0x0a] = 0xc0
  s.regs[0x31] = 0x9f
  s.lectures = 0
  s.lignes_produites = 0
retourner s

fonction SIM_R(s, a)
retourner s.regs[a] ou 0

fonction SIM_R24(s, a)
retourner SIM_R(s, a) * 65536 + SIM_R(s, a + 1) * 256 + SIM_R(s, a + 2)

fonction SIM_R16(s, a)
retourner SIM_R(s, a) * 256 + SIM_R(s, a + 1)

fonction SIM_LIRE_REG(s, a)
  faire cas
  cas a = 0x101
    locale v = 0x80
    si non s.en_cours et binaire.longueur(s.flux) = 0
      v = OU(v, 0x40)
    finsi
    si s.avance_finie
      v = OU(v, 0x20)
    finsi
    si s.en_cours et s.lignes_produites >= s.lignes_total
      v = OU(v, 0x10)
    finsi
    si s.tete <= 0.0001
      v = OU(v, 0x08)
    finsi
    si ET(SIM_R(s, 0x03), 0x10) <> 0
      v = OU(v, 0x04)
    finsi
    si s.moteur
      v = OU(v, 0x01)
    finsi
    retourner v
  cas a = 0x100
    retourner OU(0x10, OU(sisinon(s.en_cours, 0x01, 0), sisinon(s.moteur, 0x02, 0)))
  cas a >= 0x102 et a <= 0x105
    locale mots = sisinon(s.en_cours, 0x3ffff, DIVE(binaire.longueur(s.flux), 2))
    retourner ET(DECALD(mots, (0x105 - a) * 8), 0xff)
  cas a >= 0x108 et a <= 0x10a
    && compteur d'avance : la consigne FEEDL est atteinte aussitôt
    retourner SIM_R(s, 0x3d + (a - 0x108))
  cas a = 0x00
    retourner 0x24
  fincas
retourner SIM_R(s, a)

procedure SIM_ECRIRE_REG(s, a, v)
  s.regs[a] = v
  faire cas
  cas a = 0x0f
    SIM_DEMARRER(s, v = 1)
  cas a = 0x01
    si ET(v, 0x01) = 0
      s.en_cours = faux
      s.moteur = faux
    finsi
  cas a = 0x0e et v = 1
    s.regs = {}
    s.regs[0x0a] = 0xc0
    s.regs[0x31] = 0x9f
  fincas
retourner

fonction SIM_DPIHW(s)
  locale d = DECALD(ET(SIM_R(s, 0x05), 0xc0), 6)
  locale l = {600, 1200, 2400, 4800}
retourner l[d + 1]

&& déplacement de la tête (pouces) programmé par FEEDL et STEPNO
fonction SIM_AVANCE(s, double_acceleration)
  locale pas = ET(SIM_R(s, 0xa0), 0x07)
  locale stepno = SIM_R16(s, 0xa4)
  locale feedl = SIM_R24(s, 0x3d)
retourner (feedl + stepno * sisinon(double_acceleration, 2, 1)) / DECALG(1200, pas)

procedure SIM_DEMARRER(s, moteur)
  locale r02 = SIM_R(s, 0x02)
  locale alim = ET(r02, 0x10) <> 0 et moteur
  locale arriere = ET(r02, 0x04) <> 0
  locale numerise = ET(SIM_R(s, 0x01), 0x01) <> 0
  s.avance_finie = faux
  si non numerise
    && simple déplacement (scanner_move, retour à la base)
    si alim
      locale d = SIM_AVANCE(s, vrai)
      si arriere
        s.tete = max(0.0, s.tete - d)
      sinon
        s.tete += d
      finsi
    finsi
    s.avance_finie = vrai
    s.moteur = faux
    s.en_cours = faux
    retourner
  finsi
  && numérisation
  si alim et non arriere
    s.tete += SIM_AVANCE(s, faux)
  finsi
  s.avance_finie = vrai
  s.en_cours = vrai
  s.moteur = alim
  s.flux = ""
  s.lignes_produites = 0
  locale segcnt = SIM_R24(s, 0x93)
  locale dpiset = SIM_R16(s, 0x2c)
  locale dpihw = SIM_DPIHW(s)
  locale strp = SIM_R24(s, 0x82)
  locale endp = SIM_R24(s, 0x85)
  si endp = 0
    endp = segcnt
  finsi
  locale reference = dpihw
  s.xres = dpiset
  si segcnt = 0x09f8
    reference = 300
    s.xres = DIVE(dpiset, 2)
  finsi
  s.pixels = DIVE((endp - strp) * s.xres, reference)
  s.x0 = strp / reference          && unité des registres : SEGCNT pixels sur la largeur
  s.profondeur = sisinon(ET(SIM_R(s, 0x04), 0x40) <> 0, 16, 8)
  locale linesel = ET(SIM_R(s, 0x1d), 0x1f)
  s.lignes_total = DIVE(SIM_R24(s, 0x25), linesel + 1)
  locale filtre = DECALD(ET(SIM_R(s, 0x04), 0x30), 4)
  s.gris_diodes = ET(SIM_R(s, 0x60), 0x04) <> 0
  s.cycle = filtre = 0 et non s.gris_diodes
  s.canal_fixe = sisinon(filtre > 0, filtre - 1, -1)
  s.dy = sisinon(s.cycle, 1 / (3 * s.xres), 1 / s.xres)
  s.y0 = s.tete
  s.lampe = ET(SIM_R(s, 0x03), 0x10) <> 0
  locale reference_expo = SIM_R24(s, 0x7d) * 0.31
  s.gains = {SIM_R24(s, 0x8a) / reference_expo, SIM_R24(s, 0x8d) / reference_expo, SIM_R24(s, 0x90) / reference_expo}
  s.coefficient = sisinon(ET(SIM_R(s, 0x06), 0x08) <> 0, 0x4000, 0x2000)
  s.ombrage = {}
  si ET(SIM_R(s, 0x01), 0x20) <> 0
    pour i = 0 a 2
      s.ombrage[i + 1] = s.ahb[SIM_R(s, 0xd0 + i) * 8192 + 0x10000000] ou ""
    suivant
  finsi
  s.gamma = ""
  si ET(SIM_R(s, 0x05), 0x08) <> 0 et s.profondeur = 8
    pour i = 0 a 2
      && 256 mots par couleur ; le premier (GMM_Z) est dans les registres
      locale z = SIM_R(s, 0xc5 + 2 * i) * 256 + SIM_R(s, 0xc6 + 2 * i)
      locale g = s.ahb[0x01000000 + 0x200 * i] ou ""
      s.gamma = s.gamma + binaire.depuismots({z}) + binaire.extraire(g, 1, 510)
    suivant
  finsi
retourner

&& produit la ligne optique suivante
procedure SIM_LIGNE(s)
  locale k = s.lignes_produites
  locale canal = s.canal_fixe
  si s.cycle
    canal = k % 3
  finsi
  locale y = s.y0 + k * s.dy
  locale ig = sisinon(canal < 0, 2, canal + 1)
  locale o = {x = s.x0, y = y, pixels = s.pixels, resolution = s.xres, canal = canal, ;
              profondeur = s.profondeur, lampe = s.lampe, gain = s.gains[ig], ;
              decalage = s.decalage, coefficient = s.coefficient}
  si s.ombrage[ig] <> nul et binaire.longueur(s.ombrage[ig]) > 0
    o.ombrage = s.ombrage[ig]
  finsi
  si binaire.longueur(s.gamma) > 0
    && trame:capter lit la table du canal demandé (0 pour le gris)
    o.gamma = s.gamma
  finsi
  si s.donnees_nulles
    && comme l'interface de test de SANE : uniquement des zéros
    s.flux = s.flux + binaire.depuisoctets({}) + repliquer(car(0), s.pixels * DIVE(s.profondeur, 8))
  sinon
    s.flux = s.flux + s.mire:capter(o)
  finsi
  s.lignes_produites = k + 1
  si s.moteur
    s.tete = s.y0 + (k + 1) * s.dy
  finsi
retourner

fonction SIM_CONTROLE(s, rt, req, v, idx, d)
  si rt = 0xc0
    si req = 0x04 et ET(v, 0xff) = 0x8e
      locale a = DECALD(idx, 8) + sisinon(v > 0xff, 0x100, 0)
      retourner binaire.depuisoctets({SIM_LIRE_REG(s, a), 0x55})
    finsi
    si req = 0x0c et v = 0x8e
      retourner binaire.depuisoctets({0x00})
    finsi
    erreur "simulateur : requête entrante inconnue " + HEX2(req) + " " + HEX4(v)
  finsi
  si req = 0x04 et ET(v, 0xff) = 0x83
    SIM_ECRIRE_REG(s, binaire.octet(d, 1) + sisinon(v > 0xff, 0x100, 0), binaire.octet(d, 2))
    retourner 2
  finsi
  si req = 0x04 et v = 0x82
    locale n = binaire.decoder("<I", d, 5)[1]
    si idx = 0
      s.a_lire = n
    sinon
      s.ahb_adr = binaire.decoder("<I", d, 1)[1]
      s.ahb[s.ahb_adr] = ""
    finsi
    retourner 8
  finsi
  si req = 0x0c et v = 0x8c
    retourner 1
  finsi
  erreur "simulateur : requête sortante inconnue " + HEX2(req) + " " + HEX4(v)
retourner 0

fonction SIM_LIRE(s, n)
  n = min(n, s.a_lire)
  locale garde = 0
  tantque binaire.longueur(s.flux) < n
    si non s.en_cours
      sortir
    finsi
    SIM_LIGNE(s)
    garde += 1
    si garde > 200000
      sortir
    finsi
  fintantque
  locale m = min(n, binaire.longueur(s.flux))
  locale r = binaire.extraire(s.flux, 1, m)
  s.flux = binaire.extraire(s.flux, m + 1)
  s.a_lire -= m
  s.lectures += 1
retourner r

fonction SIM_ECRIRE(s, d)
  si s.ahb_adr = nul
    erreur "simulateur : écriture bulk sans en-tête"
  finsi
  s.ahb[s.ahb_adr] = s.ahb[s.ahb_adr] + d
retourner binaire.longueur(d)

&& simule un appui sur un bouton (0 numériser, 1 copier, 2 courriel, 3 fichier)
procedure SIM_APPUYER(s, bouton)
  s.regs[0x31] = ET(0x9f, NON8(DECALG(1, bouton)))
retourner

procedure SIM_RELACHER(s)
  s.regs[0x31] = 0x9f
retourner
