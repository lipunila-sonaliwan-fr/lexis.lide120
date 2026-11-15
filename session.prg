&& =====================================================================
&& session.prg - géométrie d'une numérisation et tables du moteur
&& ---------------------------------------------------------------------
&& (low.cpp : compute_session, session_adjust_output_pixels,
&&  compute_session_pixel_offsets ; motor.cpp : pentes d'accélération)
&& Une session décrit une numérisation : paramètres demandés (params) et
&& valeurs calculées (pixels optiques, octets par ligne, positions...).
&& =====================================================================

&& --- capteurs ---

fonction CAPTEUR(res, canaux)
  globale DEV
  pour chaque c dans DEV.capteurs
    si c.resolution = res et c.canaux = canaux
      retourner c
    finsi
  suivant
  erreur "aucun réglage du capteur pour " + res + " dpi, " + canaux + " canal(aux)"
retourner nul

&& exposition en vigueur (réglée par l'étalonnage des diodes)
fonction CAPTEUR_EXPO(c)
  globale DEV
  locale e = DEV.expositions[c.indice]
  si e = nul
    retourner c.exposure
  finsi
retourner e

fonction RATIO(c, x)
retourner DIVE(x * c.ratio_mul, c.ratio_div)

&& --- paramètres ---

fonction PARAMS(xres, yres, startx, starty, pixels, lignes, profondeur, canaux, mode, filtre, drapeaux)
  locale p = {xres = xres, yres = yres, startx = startx, starty = starty, pixels = pixels, ;
              requested_pixels = pixels, lines = lignes, depth = profondeur, channels = canaux, ;
              scan_mode = mode, color_filter = filtre, flags = {}}
  pour chaque d dans drapeaux ou {}
    p.flags[d] = vrai
  suivant
retourner p

fonction A_DRAPEAU(p, d)
retourner p.flags[d] = vrai

&& session_adjust_output_pixels (GL124)
fonction AJUSTER_PIXELS(output_pixels, c, xres, yres, ajuster_sortie)
  si non ajuster_sortie
    locale optical_pixels = DIVE(output_pixels * c.optical_resolution, xres)
    output_pixels = DIVE(optical_pixels * xres, c.optical_resolution)
  sinon
    si xres <= 1200
      output_pixels = DIVE(output_pixels, 4) * 4
    sinonsi xres < yres
      output_pixels = DIVE(output_pixels, 8) * 8
    sinon
      output_pixels = DIVE(output_pixels, 16) * 16
    finsi
    si xres >= 1200
      si xres < yres
        output_pixels = DIVE(output_pixels, 8) * 8
      sinon
        output_pixels = DIVE(output_pixels, 16) * 16
      finsi
    finsi
  finsi
retourner output_pixels

fonction CALCULER_SESSION(p, c)
  globale DEV
  si p.depth <> 8 et p.depth <> 16
    erreur "profondeur non prise en charge : " + p.depth
  finsi
  locale s = {params = p}
  s.full_resolution = c.full_resolution
  s.optical_resolution = c.optical_resolution
  s.output_resolution = p.xres
  si s.output_resolution > s.optical_resolution
    erreur "résolution de sortie supérieure à la résolution optique"
  finsi
  s.output_pixels = AJUSTER_PIXELS(p.pixels, c, p.xres, p.yres, faux)
  s.optical_pixels = DIVE(s.output_pixels * s.optical_resolution, s.output_resolution)
  s.output_startx = p.startx + c.output_pixel_offset
  s.num_staggered_lines = 0
  s.max_color_shift_lines = 0
  s.output_line_count = p.lines
  s.optical_line_count = sisinon(DEV.modele.is_cis, s.output_line_count * p.channels, s.output_line_count)
  s.output_channel_bytes = s.output_pixels * DIVE(p.depth, 8)
  s.output_line_bytes = s.output_channel_bytes * p.channels
  s.segment_count = 1
  s.optical_pixels_raw = s.optical_pixels
  s.output_line_bytes_raw = s.output_line_bytes
  si DEV.modele.is_cis
    s.output_line_bytes_raw = s.output_channel_bytes
  finsi
  s.conseq_pixel_dist = DIVE(DIVE(s.output_pixels, DIVE(s.full_resolution, s.optical_resolution)), s.segment_count)
  s.output_segment_pixel_group_count = DIVE(s.output_pixels, DIVE(s.full_resolution, s.optical_resolution) * s.segment_count)
  s.output_line_bytes_requested = p.requested_pixels * p.channels * DIVE(p.depth, 8)
  s.output_total_bytes_raw = s.output_line_bytes_raw * s.output_line_count
  s.output_total_bytes = s.output_line_bytes * s.output_line_count
  s.buffer_size_read = s.output_line_bytes_raw * 64
  && compute_session_pixel_offsets (GL124)
  s.pixel_startx = DIVE(s.output_startx * c.full_resolution, p.xres)
  s.pixel_endx = s.pixel_startx + s.optical_pixels_raw
  s.pixel_startx = RATIO(c, s.pixel_startx)
  s.pixel_endx = RATIO(c, s.pixel_endx)
  s.shading_pixel_offset = c.shading_pixel_offset
  s.enable_ledadd = p.channels = 1 et DEV.modele.is_cis et p.color_filter = "aucun"
  s.computed = vrai
retourner s

&& --- moteur ---

&& MotorSlope::create_from_steps (calcul en float comme dans motor.cpp)
fonction PENTE_DEPUIS_PAS(initiale, maximale, pas)
  locale vi = F32(1 / initiale)
  locale vm = F32(1 / maximale)
  locale acc = F32(F32(F32(vm * vm) - F32(vi * vi)) / (2 * pas))
retourner {initial_speed_w = initiale, max_speed_w = maximale, acceleration = acc}

&& MotorSlope::get_table_step_shifted
fonction PENTE_PAS(pente, n, type_pas)
  si n < 2
    retourner DECALD(pente.initial_speed_w, type_pas)
  finsi
  n -= 1
  locale vi = F32(1 / pente.initial_speed_w)
  locale v = F32(racine(F32(F32(vi * vi) + F32(F32(2 * pente.acceleration) * n))))
retourner DECALD(entier(F32(1 / v)), type_pas)

&& create_slope_table_for_speed : table d'accélération jusqu'à la vitesse visée
fonction TABLE_PENTE(pente, vitesse_w, type_pas, alignement, taille_min, taille_max)
  locale cible = DECALD(vitesse_w, type_pas)
  locale vmax = DECALD(pente.max_speed_w, type_pas)
  si cible >= 65535
    erreur "vitesse du moteur trop faible"
  finsi
  locale finale = max(cible, vmax)
  locale t = {}
  tantque #t < taille_max - 1
    locale v = PENTE_PAS(pente, #t, type_pas)
    si v <= finale
      sortir
    finsi
    inserer(t, v)
  fintantque
  inserer(t, finale)
  tantque #t < taille_max - 1 et (#t % alignement <> 0 ou #t < taille_min)
    inserer(t, t[#t])
  fintantque
retourner t

&& create_slope_table (pas multiplicateur 1, table de 1024 pas au plus)
fonction CREER_TABLE_PENTE(ydpi, exposition, profil)
  globale DEV
  locale vitesse = DIVE(exposition * ydpi, DEV.modele.base_ydpi)
  && les tables sont mémorisées : leur calcul (en float) est coûteux en Lexis+
  locale cle = profil.pente.initial_speed_w + "/" + profil.pente.max_speed_w + "/" + profil.pas + "/" + vitesse
  si DEV.tables_pente = nul
    DEV.tables_pente = {}
  finsi
  locale t = DEV.tables_pente[cle]
  si t = nul
    t = TABLE_PENTE(profil.pente, vitesse, profil.pas, 1, 2, 1024)
    DEV.tables_pente[cle] = t
  finsi
retourner t

&& get_motor_profile
fonction PROFIL_MOTEUR(exposition)
  globale DEV
  locale meilleur = nul
  pour chaque pr dans DEV.moteur
    si pr.exposition_max = exposition
      retourner pr
    finsi
    si pr.exposition_max = 0 ou pr.exposition_max >= exposition
      si meilleur = nul ou pr.exposition_max < meilleur.exposition_max
        meilleur = pr
      finsi
    finsi
  suivant
  si meilleur = nul
    erreur "pente du moteur non configurée pour l'exposition " + exposition
  finsi
retourner meilleur

&& sanei_genesys_calculate_zmod (une seule table)
fonction CALCULER_ZMOD(exposition, table, pas_accel, pas_deplacement, pas_tampon)
  locale somme = 0
  pour i = 1 a pas_accel
    somme += table[i]
  suivant
  locale derniere = table[pas_accel]
  locale z1 = (somme + pas_tampon * derniere) % exposition
  locale z2 = (somme + pas_deplacement * derniere) % exposition
retourner {z1 = z1, z2 = z2}
