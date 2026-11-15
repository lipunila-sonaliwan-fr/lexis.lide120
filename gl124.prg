&& =====================================================================
&& gl124.prg - commande de la puce Genesys GL124 (portage de gl124.cpp
&&             et des fonctions communes de genesys.cpp / low.cpp)
&& ---------------------------------------------------------------------
&& DEV (globale) décrit l'appareil ouvert :
&&   t            transport (usb ou simulation)
&&   modele, capteurs, moteur, frontal
&&   reg          registres en cours ; initial_regs : après l'amorçage
&&   expositions  expositions des diodes réglées par l'étalonnage
&&   tete         position de la tête en pas (nul : inconnue)
&&   session      dernière session programmée ; calib_session
&&   reglages     {xres, yres, ...} de la numérisation demandée
&& =====================================================================

&& --- registres d'état (0x101) et 0x100 ---

fonction GL_ETAT()
  locale v = GL_LIRE_REG(0x101)
  locale s = {}
  s.rebranche = ET(v, 0x80) = 0
  s.tampon_vide = ET(v, 0x40) <> 0
  s.avance_finie = ET(v, 0x20) <> 0
  s.numerisation_finie = ET(v, 0x10) <> 0
  s.a_la_base = ET(v, 0x08) <> 0
  s.lampe = ET(v, 0x04) <> 0
  s.frontal_occupe = ET(v, 0x02) <> 0
  s.moteur = ET(v, 0x01) <> 0
  s.brut = v
retourner s

fonction GL_ETAT_FIABLE()
  GL_ETAT()
  GL_DORMIR(100)
retourner GL_ETAT()

fonction GL_MOTS_VALIDES()
  locale w = ET(GL_LIRE_REG(0x102), 0x03)
  w = w * 256 + GL_LIRE_REG(0x103)
  w = w * 256 + GL_LIRE_REG(0x104)
  w = w * 256 + GL_LIRE_REG(0x105)
retourner w

fonction GL_PAS_AVANCE()
  locale s = DECALG(ET(GL_LIRE_REG(0x108), 0x1f), 16)
  s += DECALG(GL_LIRE_REG(0x109), 8)
  s += GL_LIRE_REG(0x10a)
retourner s

fonction GL_LIGNES_LUES()
  locale s = DECALG(ET(GL_LIRE_REG(0x10b), 0x0f), 16)
  s += DECALG(GL_LIRE_REG(0x10c), 8)
  s += GL_LIRE_REG(0x10d)
retourner s

fonction GL_TAMPON_VIDE()
  GL_DORMIR(1)
  locale s = GL_ETAT()
  si s.tampon_vide
    GL_DORMIR(1)
    retourner vrai
  finsi
retourner faux

procedure GL_ATTENDRE_DONNEES()
  pour i = 1 a 100000
    locale vide = GL_TAMPON_VIDE()
    GL_DORMIR(10)
    si non vide
      retourner
    finsi
    VERIFIER_ARRET()
  suivant
  erreur "le scanner n'envoie pas de données"
retourner

procedure GL_ATTENDRE_MOTS()
  locale attente = 0
  tantque attente < 70000
    si GL_MOTS_VALIDES() <> 0
      retourner
    finsi
    GL_DORMIR(10)
    attente += 10
    VERIFIER_ARRET()
  fintantque
  erreur "délai dépassé : le tampon du scanner ne se remplit pas"
retourner

&& sanei_genesys_read_data_from_scanner
fonction GL_LIRE_IMAGE(n)
  GL_ATTENDRE_MOTS()
retourner GL_LIRE_DONNEES(n)

&& --- registres par défaut (gl124_init_registers, cas du LiDE 120) ---

fonction GL_REGISTRES_INITIAUX()
  locale r = REGS_NOUVEAU()
  locale l = { ;
    {0x01, 0xa2}, {0x02, 0x90}, {0x03, 0x50}, {0x04, 0x03}, {0x05, 0x00}, {0x06, 0x50}, ;
    {0x07, 0x00}, {0x09, 0x00}, {0x0a, 0xc0}, {0x0b, 0x2a}, {0x0c, 0x12}, {0x11, 0x00}, ;
    {0x12, 0x00}, {0x13, 0x0f}, {0x14, 0x00}, {0x15, 0x80}, {0x16, 0x10}, {0x17, 0x04}, ;
    {0x18, 0x00}, {0x19, 0x01}, {0x1a, 0x30}, {0x1b, 0x00}, {0x1c, 0x00}, {0x1d, 0x01}, ;
    {0x1e, 0x10}, {0x1f, 0x00}, {0x20, 0x15}, {0x21, 0x00}, {0x22, 0x14}, {0x23, 0x00}, ;
    {0x24, 0x00}, {0x25, 0x00}, {0x26, 0x0d}, {0x27, 0x48}, {0x28, 0x00}, {0x29, 0x56}, ;
    {0x2a, 0x5e}, {0x2b, 0x02}, {0x2c, 0x02}, {0x2d, 0x58}, {0x3b, 0x00}, {0x3c, 0x00}, ;
    {0x3d, 0x00}, {0x3e, 0x00}, {0x3f, 0x02}, {0x40, 0x00}, {0x41, 0x00}, {0x42, 0x00}, ;
    {0x43, 0x00}, {0x44, 0x00}, {0x45, 0x00}, {0x46, 0x00}, {0x47, 0x00}, {0x48, 0x00}, ;
    {0x49, 0x00}, {0x4f, 0x00}, {0x52, 0x00}, {0x53, 0x02}, {0x54, 0x04}, {0x55, 0x06}, ;
    {0x56, 0x04}, {0x57, 0x04}, {0x58, 0x04}, {0x59, 0x04}, {0x5a, 0x1a}, {0x5b, 0x00}, ;
    {0x5c, 0xc0}, {0x5f, 0x00}, {0x60, 0x02}, {0x61, 0x00}, {0x62, 0x00}, {0x63, 0x00}, ;
    {0x64, 0x00}, {0x65, 0x00}, {0x66, 0x00}, {0x67, 0x00}, {0x68, 0x00}, {0x69, 0x00}, ;
    {0x6a, 0x00}, {0x6b, 0x00}, {0x6c, 0x00}, {0x6e, 0x00}, {0x6f, 0x00}, {0x6d, 0x00}, ;
    {0x71, 0x1f}, {0x70, 0x00}, {0x71, 0x08}, {0x72, 0x08}, {0x73, 0x0a}, {0x74, 0x00}, ;
    {0x75, 0x00}, {0x76, 0x3c}, {0x77, 0x00}, {0x78, 0x00}, {0x79, 0x9f}, {0x7a, 0x00}, ;
    {0x7b, 0x00}, {0x7c, 0x55}, {0x7d, 0x00}, {0x7e, 0x08}, {0x7f, 0x58}, {0x80, 0x00}, ;
    {0x81, 0x10}, {0x82, 0x00}, {0x83, 0x00}, {0x84, 0x00}, {0x85, 0x00}, {0x86, 0x00}, ;
    {0x87, 0x00}, {0x88, 0x00}, {0x89, 0x65}, {0x8a, 0x00}, {0x8b, 0x00}, {0x8c, 0x00}, ;
    {0x8d, 0x00}, {0x8e, 0x00}, {0x8f, 0x00}, {0x90, 0x00}, {0x91, 0x00}, {0x92, 0x00}, ;
    {0x93, 0x00}, {0x94, 0x14}, {0x95, 0x30}, {0x96, 0x00}, {0x97, 0x90}, {0x98, 0x01}, ;
    {0x99, 0x1f}, {0x9a, 0x00}, {0x9b, 0x80}, {0x9c, 0x80}, {0x9d, 0x3f}, {0x9e, 0x00}, ;
    {0x9f, 0x00}, {0xa0, 0x20}, {0xa1, 0x30}, {0xa2, 0x00}, {0xa3, 0x20}, {0xa4, 0x01}, ;
    {0xa5, 0x00}, {0xa6, 0x00}, {0xa7, 0x08}, {0xa8, 0x00}, {0xa9, 0x08}, {0xaa, 0x01}, ;
    {0xab, 0x00}, {0xac, 0x00}, {0xad, 0x40}, {0xae, 0x01}, {0xaf, 0x00}, {0xb0, 0x00}, ;
    {0xb1, 0x40}, {0xb2, 0x00}, {0xb3, 0x09}, {0xb4, 0x5b}, {0xb5, 0x00}, {0xb6, 0x10}, ;
    {0xb7, 0x3f}, {0xb8, 0x00}, {0xbb, 0x00}, {0xbc, 0xff}, {0xbd, 0x00}, {0xbe, 0x07}, ;
    {0xc3, 0x00}, {0xc4, 0x00}, {0xc5, 0x20}, {0xc6, 0xeb}, {0xc7, 0x20}, {0xc8, 0xeb}, ;
    {0xc9, 0x20}, {0xca, 0xeb}, {0xd3, 0x00}, {0xd4, 0x00}, {0xd5, 0x00}, {0xd6, 0x00}, ;
    {0xd7, 0x00}, {0xd8, 0x00}, {0xd9, 0x00}, {0xf8, 0x01}, {0xf9, 0x00}, {0xfa, 0x00}, ;
    {0xfb, 0x00}, {0xfc, 0x00}, {0xff, 0x00}}
  pour chaque x dans l
    REGS_INIT(r, x[1], x[2])
  suivant
  && dpihw du capteur à pleine résolution, en couleur
  GL_FIXER_DPIHW(r, CAPTEUR(2400, 3).register_dpihw)
retourner r

procedure GL_FIXER_DPIHW(r, dpihw)
  locale v = 0
  faire cas
  cas dpihw = 600
    v = 0x00
  cas dpihw = 1200
    v = 0x40
  cas dpihw = 2400
    v = 0x80
  cas dpihw = 4800
    v = 0xc0
  autrement
    erreur "dpihw inconnu : " + dpihw
  fincas
  REGS_SET8_MASQUE(r, 0x05, v, 0xc0)
retourner

procedure GL_FIXER_EXPOSITION(r, e)
  REGS_SET24(r, 0x8a, e.r)
  REGS_SET24(r, 0x8d, e.g)
  REGS_SET24(r, 0x90, e.b)
retourner

procedure GL_LAMPE(r, allumee)
  si allumee
    REGS_ALLUMER(r, 0x03, 0x10)
  sinon
    REGS_ETEINDRE(r, 0x03, 0x10)
  finsi
retourner

procedure GL_MOTEUR_ALIM(r, alim)
  si alim
    REGS_ALLUMER(r, 0x02, 0x10)
  sinon
    REGS_ETEINDRE(r, 0x02, 0x10)
  finsi
retourner

&& --- frontal analogique ---

procedure GL_FRONTAL(init)
  globale DEV
  si init
    DEV.frontal = copier(DEV.frontal_initial)
  finsi
  locale v = GL_LIRE_REG(0x0a)
  si DECALD(ET(v, 0xc0), 6) <> 3
    erreur "frontal analogique non pris en charge (" + HEX2(v) + ")"
  finsi
  locale f = DEV.frontal
  GL_FE_ECRIRE(0x00, 0x80)
  GL_FE_ECRIRE(0x01, f.r01)
  GL_FE_ECRIRE(0x02, f.r02)
  GL_FE_ECRIRE(0x03, f.r03)
  GL_FE_ECRIRE(0x04, 0x00)
  GL_FE_ECRIRE(0x05, f.r24)
  GL_FE_ECRIRE(0x06, f.r25)
  GL_FE_ECRIRE(0x07, f.r26)
  GL_FE_ECRIRE(0x00, 0x01)
retourner

&& --- tables du moteur (mémoire AHB 0x10000000 + 0x4000 × n) ---

procedure GL_ENVOYER_PENTE(n, table)
  GL_AHB(0x10000000 + 0x4000 * n, binaire.depuismots(table))
retourner

&& --- programmation d'une numérisation ---

&& gl124_init_motor_regs_scan
procedure GL_REGS_MOTEUR(c, r, profil, exposition, scan_yres, lignes, pas_avance, mode, p)
  globale DEV
  locale min_speed = 900
  locale yres, linesel
  si scan_yres < min_speed
    yres = min_speed
    linesel = DIVE(yres, scan_yres) - 1
    si linesel = 0
      linesel = 1
      yres = scan_yres * 2
    finsi
  sinon
    yres = scan_yres
    linesel = 0
  finsi
  REGS_SET24(r, 0x25, lignes * (linesel + 1))
  locale r02 = 0x80
  si A_DRAPEAU(p, "AUTO_GO_HOME")
    r02 = OU(r02, 0x20)
  finsi
  si A_DRAPEAU(p, "DISABLE_BUFFER_FULL_MOVE") ou yres >= c.full_resolution
    r02 = OU(r02, 0x40)
  finsi
  si A_DRAPEAU(p, "REVERSE")
    r02 = OU(r02, 0x04)
  finsi
  REGS_SET8(r, 0x02, r02)
  GL_MOTEUR_ALIM(r, vrai)
  REGS_SET16(r, 0xa2, 4)
  locale table = CREER_TABLE_PENTE(yres, exposition, profil)
  GL_ENVOYER_PENTE(0, table)
  GL_ENVOYER_PENTE(1, table)
  REGS_SET16(r, 0xa4, #table)
  locale rapide = CREER_TABLE_PENTE(yres, exposition, profil)
  GL_ENVOYER_PENTE(2, rapide)
  GL_ENVOYER_PENTE(3, rapide)
  REGS_SET16(r, 0xaa, #rapide)
  REGS_SET16(r, 0xac, #rapide)
  REGS_SET16(r, 0xae, #rapide)
  locale feedl = DECALG(pas_avance, profil.pas)
  locale dist = #table
  si A_DRAPEAU(p, "FEEDING")
    dist = dist * 2
  finsi
  si dist < feedl
    feedl -= dist
  sinon
    feedl = 0
  finsi
  REGS_SET24(r, 0x3d, feedl)
  locale z = CALCULER_ZMOD(exposition, table, #table, feedl, #table)
  REGS_SET24(r, 0xb2, z.z1)
  REGS_SET24(r, 0xb5, z.z2)
  REGS_SET8_MASQUE(r, 0x1d, linesel, 0x1f)
  REGS_SET8(r, 0xa0, OU(profil.pas, DECALG(profil.pas, 3)))
  REGS_SET16(r, 0xb0, #rapide)
retourner

fonction GAMMA_ACTIF(s, c)
  locale p = s.params
  si A_DRAPEAU(p, "DISABLE_GAMMA") ou p.depth = 16
    retourner faux
  finsi
  pour chaque g dans c.gamma
    si g = 1.0
      retourner faux
    finsi
  suivant
retourner vrai

&& gl124_init_optical_regs_scan
procedure GL_REGS_OPTIQUES(c, r, exposition, s)
  globale DEV
  locale p = s.params
  && scanner_setup_sensor
  pour chaque x dans c.custom_regs
    REGS_SET8(r, x[1], x[2])
  suivant
  GL_FIXER_EXPOSITION(r, CAPTEUR_EXPO(c))
  GL_FRONTAL(faux)
  REGS_ETEINDRE(r, 0x01, 0x01)
  si A_DRAPEAU(p, "DISABLE_SHADING")
    REGS_ETEINDRE(r, 0x01, 0x20)
  sinon
    REGS_ALLUMER(r, 0x01, 0x20)
  finsi
  && LiDE 120 : SANE positionne ici tous les bits sauf AVEENB (« BUG » signalé
  && dans gl124.cpp) ; le comportement est conservé tel quel.
  REGS_ALLUMER(r, 0x03, 0xbf)
  GL_LAMPE(r, non A_DRAPEAU(p, "DISABLE_LAMP"))
  GL_ECRIRE_REG(0x114, 0x7f)
  GL_ECRIRE_REG(0x115, 0x7f)
  si p.depth = 8
    REGS_ETEINDRE(r, 0x04, 0xc0)
  sinon
    REGS_ETEINDRE(r, 0x04, 0x80)
    REGS_ALLUMER(r, 0x04, 0x40)
  finsi
  REGS_ETEINDRE(r, 0x04, 0x30)
  si p.channels = 1
    faire cas
    cas p.color_filter = "rouge"
      REGS_ALLUMER(r, 0x04, 0x10)
    cas p.color_filter = "bleu"
      REGS_ALLUMER(r, 0x04, 0x30)
    cas p.color_filter = "vert"
      REGS_ALLUMER(r, 0x04, 0x20)
    fincas
  finsi
  GL_FIXER_DPIHW(r, CAPTEUR(s.output_resolution, p.channels).register_dpihw)
  si GAMMA_ACTIF(s, c)
    REGS_ALLUMER(r, 0x05, 0x08)
  sinon
    REGS_ETEINDRE(r, 0x05, 0x08)
  finsi
  REGS_SET16(r, 0x2c, c.register_dpiset)
  REGS_ALLUMER(r, 0x06, 0x08)
  && CIS : gris vrai par addition des trois diodes (LEDADD)
  REGS_ETEINDRE(r, 0x60, 0x04)
  si s.enable_ledadd
    REGS_ALLUMER(r, 0x60, 0x04)
    locale emax = max(REGS_GET24(r, 0x8a), REGS_GET24(r, 0x8d), REGS_GET24(r, 0x90))
    GL_FIXER_EXPOSITION(DEV.reg, {r = emax, g = emax, b = emax})
  finsi
  REGS_ETEINDRE(r, 0x01, 0x04)
  si s.enable_ledadd
    REGS_ALLUMER(r, 0x01, 0x04)
    GL_ECRIRE_REG(0x110, 0x80)
    GL_ECRIRE_REG(0x111, 0x80)
    GL_ECRIRE_REG(0x112, 0x80)
  finsi
  locale fin = s.pixel_endx
  si fin = REGS_GET24(r, 0x93)
    fin = 0
  finsi
  REGS_SET24(r, 0x82, s.pixel_startx)
  REGS_SET24(r, 0x85, fin)
  REGS_SET24(r, 0x28, DIVE(s.output_line_bytes_raw * p.channels * s.optical_resolution, s.full_resolution))
  REGS_SET24(r, 0x7d, exposition)
  REGS_SET16(r, 0x80, c.dummy_pixel)
retourner

&& init_regs_for_scan_session
procedure GL_PROGRAMMER(c, r, s)
  globale DEV
  locale p = s.params
  locale slope_dpi = sisinon(DEV.modele.is_cis, p.yres * p.channels, p.yres)
  locale exposition = sisinon(A_DRAPEAU(p, "FEEDING"), 2304, c.exposure_lperiod)
  locale profil = PROFIL_MOTEUR(exposition)
  GL_REGS_OPTIQUES(c, r, exposition, s)
  GL_REGS_MOTEUR(c, r, profil, exposition, slope_dpi, s.optical_line_count, p.starty, p.scan_mode, p)
  DEV.session = s
retourner

&& --- marche et arrêt ---

procedure GL_GPIO_NUMERISATION(res)
  locale v = GL_LIRE_REG(0x32)
  si res <= 300
    v = ET(v, 0xf7)
  sinonsi res <= 600
    v = OU(v, 0x08)
  sinonsi res <= 1200
    v = OU(ET(v, 0xef), 0x08)
  sinon
    v = ET(v, 0xf7)
  finsi
  GL_ECRIRE_REG(0x32, OU(v, 0x02))
retourner

procedure GL_EFFACER_COMPTEURS()
  GL_ECRIRE_REG(0x0d, 0x05)
retourner

procedure GL_DEMARRER_ACTION(moteur)
  GL_ECRIRE_REG(0x0f, sisinon(moteur, 0x01, 0x00))
retourner

procedure GL_AVANCER_TETE(sens_inverse, pas)
  globale DEV
  si DEV.tete = nul
    erreur "position de la tête inconnue"
  finsi
  si sens_inverse
    si DEV.tete < pas
      DEV.tete = 0
    sinon
      DEV.tete -= pas
    finsi
  sinon
    DEV.tete += pas
  finsi
retourner

procedure GL_DEBUT(c, r, moteur)
  globale DEV
  GL_GPIO_NUMERISATION(DEV.reglages.yres)
  GL_EFFACER_COMPTEURS()
  GL_ECRIRE_REG(0x01, OU(GL_LIRE_REG(0x01), 0x01))
  GL_DEMARRER_ACTION(moteur)
  locale s = DEV.session
  GL_AVANCER_TETE(A_DRAPEAU(s.params, "REVERSE"), s.params.starty + DIVE(s.params.lines * DEV.modele.base_ydpi, s.params.yres))
retourner

procedure GL_CAPTEUR_BASE_GPIO()
  GL_ECRIRE_REG(0x32, ET(GL_LIRE_REG(0x32), NON8(0x02)))
retourner

fonction GL_MOTEUR_ARRETE()
  locale s = GL_ETAT()
  locale r = GL_LIRE_REG(0x100)
retourner ET(r, 0x01) = 0 et ET(r, 0x02) = 0 et non s.moteur

procedure GL_ARRET_SANS_DEPLACEMENT(r)
  REGS_ETEINDRE(r, 0x01, 0x01)
  GL_ECRIRE_REG(0x01, REGS_GET8(r, 0x01))
  GL_DORMIR(100)
retourner

&& scanner_stop_action
procedure GL_ARRETER()
  globale DEV
  GL_CAPTEUR_BASE_GPIO()
  si GL_MOTEUR_ARRETE()
    retourner
  finsi
  GL_ARRET_SANS_DEPLACEMENT(DEV.reg)
  pour i = 1 a 10
    si GL_MOTEUR_ARRETE()
      retourner
    finsi
    GL_DORMIR(100)
  suivant
  erreur "impossible d'arrêter le moteur"
retourner

procedure GL_ATTENDRE_ARRET_MOTEUR()
  locale s = GL_ETAT()
  locale v = GL_LIRE_REG(0x100)
  si non s.moteur et ET(v, 0x02) = 0
    retourner
  finsi
  locale n = 0
  tantque s.moteur ou ET(v, 0x02) <> 0
    GL_DORMIR(10)
    s = GL_ETAT()
    v = GL_LIRE_REG(0x100)
    n += 1
    si n > 3000
      erreur "le moteur ne s'arrête pas"
    finsi
  fintantque
  GL_DORMIR(50)
retourner

&& scanner_move : avance ou recul de la tête de n pas (base_ydpi / 4)
procedure GL_DEPLACER(pas, arriere)
  globale DEV
  locale r = REGS_COPIE(DEV.reg)
  locale res = 75
  locale c = CAPTEUR(res, 3)
  si DEV.tete = nul
    erreur "position de la tête inconnue"
  finsi
  si arriere et pas > DEV.tete
    erreur "déplacement au-delà de la position de repos (" + pas + " > " + DEV.tete + ")"
  finsi
  locale drapeaux = {"DISABLE_SHADING", "DISABLE_GAMMA", "FEEDING", "IGNORE_STAGGER_OFFSET", ;
                     "IGNORE_COLOR_OFFSET", "DISABLE_BUFFER_FULL_MOVE"}
  si arriere
    inserer(drapeaux, "REVERSE")
  finsi
  locale p = PARAMS(res, res, 0, pas, 50, 3, 8, 1, "gris", "vert", drapeaux)
  locale s = CALCULER_SESSION(p, c)
  GL_PROGRAMMER(c, r, s)
  && expositions minimales pendant un simple déplacement (genesys.cpp)
  GL_FIXER_EXPOSITION(r, {r = 1, g = 1, b = 1})
  GL_EFFACER_COMPTEURS()
  GL_ECRIRE_REGS(r)
  GL_DEMARRER_ACTION(vrai)
  NOTER_ECRITURE("# feed")
  locale t0 = systeme.horloge()
  tantque vrai
    locale st = GL_ETAT()
    si st.avance_finie ou (arriere et st.a_la_base)
      sortir
    finsi
    GL_DORMIR(10)
    si systeme.horloge() - t0 > 60
      GL_ARRETER()
      erreur "déplacement de la tête : délai dépassé"
    finsi
  fintantque
  GL_ARRETER()
  GL_AVANCER_TETE(arriere, pas)
  GL_DORMIR(100)
retourner

&& scanner_move_back_home : retour lent jusqu'au capteur de position de repos
procedure GL_RETOUR_BASE(attendre)
  globale DEV
  si DEV.tete <> nul et DEV.tete > 1000
    GL_DEPLACER(DEV.tete - 500, vrai)
  finsi
  GL_CAPTEUR_BASE_GPIO()
  si GL_ETAT_FIABLE().a_la_base
    DEV.tete = 0
    retourner
  finsi
  locale r = REGS_COPIE(DEV.reg)
  locale res = 75
  locale c = CAPTEUR(res, 1)
  locale p = PARAMS(res, res, 0, 40000, 50, 3, 8, 1, "gris", "vert", ;
                    {"DISABLE_SHADING", "DISABLE_GAMMA", "IGNORE_STAGGER_OFFSET", "IGNORE_COLOR_OFFSET", "REVERSE"})
  locale s = CALCULER_SESSION(p, c)
  GL_PROGRAMMER(c, r, s)
  GL_EFFACER_COMPTEURS()
  GL_ECRIRE_REGS(r)
  GL_GPIO_NUMERISATION(res)
  GL_DEMARRER_ACTION(vrai)
  GL_CAPTEUR_BASE_GPIO()
  NOTER_ECRITURE("# move_back_home")
  si attendre
    pour i = 1 a 300
      si GL_ETAT().a_la_base
        DEV.tete = 0
        retourner
      finsi
      GL_DORMIR(100)
    suivant
    essayer
      GL_ARRETER()
    capturer e
    finessayer
    DEV.tete = nul
    erreur "délai dépassé : la tête ne revient pas en position de repos"
  finsi
retourner

&& --- gamma (sanei_genesys_send_gamma_table) ---

procedure GL_ENVOYER_GAMMA(c)
  locale taille = 257
  pour i = 0 a 2
    locale g = c.gamma[i + 1]
    locale table = {}
    pour k = 0 a taille - 1
      && sanei_genesys_create_gamma_table : valeur arrondie en float
      locale v = F32(65535 * ((k / taille) ^ (1 / F32(g))))
      inserer(table, min(entier(v), 65535))
    suivant
    GL_ECRIRE_REG(0xbd, ET(GL_LIRE_REG(0xbd), NON8(DECALG(1, i))))
    GL_ECRIRE_REG(0xbe, ET(GL_LIRE_REG(0xbe), NON8(DECALG(1, i))))
    table[taille] = 0
    && GMM_Z : premier mot (octet de poids fort puis faible)
    GL_ECRIRE_REG(0xc5 + 2 * i, DECALD(table[1], 8))
    GL_ECRIRE_REG(0xc6 + 2 * i, ET(table[1], 0xff))
    locale suite = {}
    pour k = 2 a taille
      inserer(suite, table[k])
    suivant
    GL_AHB(0x01000000 + 0x200 * i, binaire.depuismots(suite))
  suivant
retourner

&& --- amorçage et initialisation ---

procedure GL_AMORCER(froid)
  globale DEV
  si froid
    GL_ECRIRE_REG(0x0e, 0x01)
    GL_ECRIRE_REG(0x0e, 0x00)
  finsi
  GL_ECRIRE_REG(0x36, 0x01)
  GL_ECRIRE_REG(0x33, OU(GL_LIRE_REG(0x33), 0x01))
  locale v = GL_LIRE_REG(0x100)
  si ET(v, 0x10) <> 0
    DEV.version_puce = GL_LIRE_REG(0x00)
  finsi
  DEV.reg = GL_REGISTRES_INITIAUX()
  GL_ECRIRE_REGS(DEV.reg)
  GL_ECRIRE_REG(0x0b, OU(0x20, OU(0x08, 0x02)))
  REGS_RETIRER(DEV.reg, 0x0b)
  GL_ECRIRE_8C(0x10, 0x0b)
  GL_ECRIRE_8C(0x13, 0x0e)
  REGS_INIT(DEV.reg, 0x08, 0x10)
  GL_ECRIRE_REG(0x08, 0x10)
  pour chaque x dans LIDE120_GPIO()
    GL_ECRIRE_REG(x[1], x[2])
  suivant
  pour chaque x dans LIDE120_MEMOIRE()
    GL_ECRIRE_REG(x[1], x[2])
  suivant
retourner

&& sanei_genesys_asic_init
procedure GL_INITIALISER()
  globale DEV
  locale m = T_CONTROLE(DEV.tr, RT_IN(), 0x0c, 0x8e, 0x00, 1)
  DEV.usb_mode = sisinon(ET(binaire.octet(m, 1) ou 0, 0x08) <> 0, 1, 2)
  locale froid = ET(GL_LIRE_REG(0x06), 0x10) = 0
  si DEV.initialise et non froid
    retourner
  finsi
  JOURNAL("amorçage de la puce" + sisinon(froid, " (démarrage à froid)", ""))
  GL_AMORCER(froid)
  DEV.blanc = nul
  DEV.noir = nul
  DEV.initial_regs = REGS_COPIE(DEV.reg)
  GL_FRONTAL(vrai)
  DEV.initialise = vrai
  JOURNAL("retour de la tête en position de repos")
  GL_RETOUR_BASE(vrai)
  && set_powersaving(15)
  REGS_SET8(DEV.reg, 0x03, OU(ET(REGS_GET8(DEV.reg, 0x03), NON8(0xf0)), 0x0f))
retourner
