&& =====================================================================
&& etalonnage.prg - étalonnage du LiDE 120 (genesys.cpp, gl124.cpp)
&& ---------------------------------------------------------------------
&&   1. diodes : on lit la bande blanche sous le capot et on ajuste
&&      l'exposition de chaque couleur jusqu'à viser 200 × 256 (16 bits) ;
&&   2. noir : lecture lampe éteinte (courant d'obscurité de chaque pixel) ;
&&   3. blanc : lecture de la bande blanche (sensibilité de chaque pixel) ;
&&   4. coefficients d'ombrage envoyés au circuit, qui corrige chaque pixel :
&&      sortie = (brut - noir) × gain / 0x4000, avec
&&      gain = 0x4000 × 0xc000 / (blanc - noir).
&& Le décalage et le gain du frontal ne sont pas étalonnés sur ce modèle
&& (frontal de type TI : SANE les laisse aux valeurs d'usine).
&& =====================================================================

&& gl124 move_to_calibration_area : ligne à 600 dpi, moteur en marche
procedure CAL_ZONE_ETALONNAGE()
  globale DEV
  locale res = 600
  locale c = CAPTEUR(res, 3)
  locale r = REGS_COPIE(DEV.reg)
  locale pixels = entier(DEV.modele.x_size_calib_mm * res / DEV.modele.mm_par_pouce)
  locale p = PARAMS(res, res, 0, 0, pixels, 1, 8, 3, "couleur", DEV.reglages.color_filter, ;
                    {"DISABLE_SHADING", "DISABLE_GAMMA", "SINGLE_LINE", "IGNORE_STAGGER_OFFSET", "IGNORE_COLOR_OFFSET"})
  locale s = CALCULER_SESSION(p, c)
  GL_PROGRAMMER(c, r, s)
  GL_ECRIRE_REGS(r)
  GL_DEBUT(c, r, vrai)
  NOTER_ECRITURE("# move_to_calibration_area")
  GL_LIRE_IMAGE(s.output_line_bytes)
  GL_ARRETER()
retourner

&& scanner_led_calibration (GL124)
fonction CAL_DIODES(capteur)
  globale DEV
  CAL_ZONE_ETALONNAGE()
  locale res = capteur.shading_resolution
  locale c = CAPTEUR(res, 3)
  locale r = REGS_COPIE(DEV.reg)
  locale pixels = entier(DEV.modele.x_size_calib_mm * res / DEV.modele.mm_par_pouce)
  locale p = PARAMS(res, res, 0, 0, pixels, 1, 16, 3, "couleur", DEV.reglages.color_filter, ;
                    {"DISABLE_SHADING", "DISABLE_GAMMA", "SINGLE_LINE", "IGNORE_STAGGER_OFFSET", "IGNORE_COLOR_OFFSET"})
  locale s = CALCULER_SESSION(p, c)
  GL_PROGRAMMER(c, r, s)
  locale e0 = CAPTEUR_EXPO(c)
  locale expo = {e0.r, e0.g, e0.b}
  locale cible = capteur.gain_white_ref * 256
  GL_MOTEUR_ALIM(r, faux)
  locale bon = faux
  locale essai = 0
  tantque essai < 100 et non bon
    essai += 1
    GL_FIXER_EXPOSITION(r, {r = expo[1], g = expo[2], b = expo[3]})
    GL_ECRIRE_REGS(r)
    GL_DEBUT(c, r, vrai)
    NOTER_ECRITURE("# led_calibration")
    locale d = GL_LIRE_IMAGE(s.output_line_bytes)
    GL_ARRETER()
    locale moy = trame.moyennes16(d, 3)
    bon = vrai
    pour i = 1 a 3
      locale m = entier(moy[i])
      si abs(m - cible) > DIVE(cible, 50)
        si m <> 0
          expo[i] = entier(expo[i] * 0.5 + DIVE(expo[i] * cible, m) * 0.5)
        sinon
          expo[i] = entier(expo[i] * 0.5 + expo[i] * 10 * 0.5)
        finsi
        expo[i] = max(1, min(expo[i], 65535))
        bon = faux
      finsi
    suivant
    JOURNAL("  diodes, essai " + essai + " : moyennes " + entier(moy[1]) + " " + entier(moy[2]) + " " + ;
            entier(moy[3]) + " (cible " + cible + ") → expositions " + joindre(expo, " "))
    VERIFIER_ARRET()
  fintantque
  locale e = {r = expo[1], g = expo[2], b = expo[3]}
  GL_FIXER_EXPOSITION(DEV.reg, e)
retourner e

&& gl124 init_regs_for_shading
fonction CAL_REGS_OMBRAGE(capteur, r)
  globale DEV
  locale res = capteur.shading_resolution
  locale lignes = entier(DEV.modele.y_size_calib_mm * res / DEV.modele.mm_par_pouce)
  locale c = CAPTEUR(res, 3)
  locale avance = 0
  si DEV.reglages.yres >= 1200
    avance = entier(entier(DEV.modele.y_offset_calib_white) * DIVE(DEV.modele.base_ydpi, 4) / DEV.modele.mm_par_pouce)
  finsi
  locale pixels = entier(DEV.modele.x_size_calib_mm * res / DEV.modele.mm_par_pouce)
  locale p = PARAMS(res, res, 0, avance, pixels, lignes, 16, 3, "couleur", "rouge", ;
                    {"DISABLE_SHADING", "DISABLE_GAMMA", "DISABLE_BUFFER_FULL_MOVE"})
  locale s = CALCULER_SESSION(p, c)
  GL_PROGRAMMER(c, r, s)
  GL_MOTEUR_ALIM(r, faux)
  DEV.calib_session = s
retourner s

&& genesys_shading_calibration_impl : moyenne (médiane) de chaque pixel
fonction CAL_OMBRAGE(capteur, noir)
  globale DEV
  locale r = REGS_COPIE(DEV.reg)
  locale s = CAL_REGS_OMBRAGE(capteur, r)
  GL_ECRIRE_REGS(r)
  locale pixels = s.params.pixels
  locale canaux = s.params.channels
  locale n = canaux * 2 * pixels * (s.params.lines + 1)
  GL_LAMPE(r, non noir)
  GL_MOTEUR_ALIM(r, vrai)
  GL_ECRIRE_REGS(r)
  si noir
    GL_DORMIR(200)
  sinon
    GL_DORMIR(500)
  finsi
  GL_DEBUT(capteur, r, non noir)
  NOTER_ECRITURE(sisinon(noir, "# dark_shading_calibration", "# white_shading_calibration"))
  locale d = GL_LIRE_IMAGE(n)
  GL_ARRETER()
retourner trame.mediane16(d, s.params.lines, pixels * canaux, 0.5)

&& compute_coefficient
fonction CAL_COEFFICIENT(coeff, cible, v)
  si v > 0
    locale x = DIVE(coeff * cible, v)
    retourner min(x, 65535)
  finsi
retourner coeff

&& genesys_send_shading_coefficient + gl124 send_shading_data
procedure CAL_ENVOYER_OMBRAGE(capteur)
  globale DEV
  locale cs = DEV.calib_session
  si cs = nul ou DEV.noir = nul ou DEV.blanc = nul
    retourner
  finsi
  locale ppl = cs.params.pixels
  locale coeff = sisinon(ET(REGS_GET8(DEV.reg, 0x06), 0x08) <> 0, 0x4000, 0x2000)
  locale cible = 0xc000
  locale s = DEV.session
  locale debut = s.pixel_startx
  locale octets = (s.pixel_endx - s.pixel_startx) * 4
  locale sf = capteur.shading_factor
  pour i = 0 a 2
    locale buf = {}
    locale x = 0
    tantque x < octets
      locale q = debut + DIVE(x, 4)
      si q < ppl
        locale dk = DEV.noir[q + ppl * i + 1]
        locale br = DEV.blanc[q + ppl * i + 1]
        locale g = 0
        si br < dk
          g = 0
        sinon
          g = CAL_COEFFICIENT(coeff, cible, br - dk)
        finsi
        inserer(buf, ET(dk, 0xff))
        inserer(buf, DECALD(dk, 8))
        inserer(buf, ET(g, 0xff))
        inserer(buf, DECALD(g, 8))
      sinon
        inserer(buf, 0)
        inserer(buf, 0)
        inserer(buf, 0)
        inserer(buf, 0)
      finsi
      x += 4 * sf
    fintantque
    tantque #buf < octets
      inserer(buf, 0)
    fintantque
    locale adr = GL_LIRE_REG(0xd0 + i) * 8192 + 0x10000000
    GL_AHB(adr, binaire.depuisoctets(buf))
  suivant
retourner

&& --- cache des étalonnages (genesys_restore / save_calibration) ---

fonction CAL_CLE(s)
  locale p = s.params
retourner p.xres + "/" + p.yres + "/" + p.channels + "/" + p.startx + "/" + p.pixels

fonction CAL_RESTAURER(capteur, s)
  globale DEV
  locale e = DEV.cache[CAL_CLE(s)]
  si e = nul
    retourner faux
  finsi
  si systeme.horloge() - e.temps > DEV.expiration * 60
    retourner faux
  finsi
  DEV.expositions[capteur.indice] = e.exposition
  DEV.calib_session = e.calib_session
  DEV.noir = e.noir
  DEV.blanc = e.blanc
retourner vrai

procedure CAL_MEMORISER(capteur, s)
  globale DEV
  DEV.cache[CAL_CLE(s)] = {exposition = CAPTEUR_EXPO(capteur), calib_session = DEV.calib_session, ;
                           noir = DEV.noir, blanc = DEV.blanc, temps = systeme.horloge()}
retourner

procedure CAL_OUBLIER()
  globale DEV
  DEV.cache = {}
retourner

&& genesys_flatbed_calibration
procedure CAL_ETALONNER(capteur)
  globale DEV
  ETAPE("Étalonnage des diodes", 0.05)
  locale e = CAL_DIODES(capteur)
  pour chaque c dans DEV.capteurs
    DEV.expositions[c.indice] = e
  suivant
  ETAPE("Étalonnage du noir", 0.12)
  DEV.noir = CAL_OMBRAGE(capteur, vrai)
  GL_RETOUR_BASE(vrai)
  ETAPE("Étalonnage du blanc", 0.18)
  DEV.blanc = CAL_OMBRAGE(capteur, faux)
  GL_RETOUR_BASE(vrai)
  JOURNAL("  noir moyen " + MOYENNE_LISTE(DEV.noir) + ", blanc moyen " + MOYENNE_LISTE(DEV.blanc))
retourner

fonction MOYENNE_LISTE(l)
  si l = nul ou #l = 0
    retourner 0
  finsi
  locale s = 0
  pour chaque v dans l
    s += v
  suivant
retourner entier(s / #l)
