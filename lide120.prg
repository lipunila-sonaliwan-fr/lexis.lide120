&& =====================================================================
&& lide120.prg - description du Canon CanoScan LiDE 120 (puce GL124)
&& ---------------------------------------------------------------------
&& Valeurs reprises du pilote genesys de SANE (sane-backends 1.4.0,
&& backend/genesys : tables_model.cpp, tables_sensor.cpp, tables_motor.cpp,
&& tables_frontend.cpp, tables_gpo.cpp, tables_memory_layout.cpp, gl124.cpp),
&& logiciel libre sous licence GNU GPL 2 ou ultérieure : ce portage en
&& Lexis+ en est une œuvre dérivée et suit la même licence.
&& =====================================================================

fonction LIDE120_MODELE()
  locale m = {}
  m.nom = "Canon CanoScan LiDE 120"
  m.vendeur = 0x04a9
  m.produit = 0x190e
  m.resolutions_x = {2400, 1200, 600, 300, 150, 100, 75}
  m.resolutions_y = {4800, 2400, 1200, 600, 300, 150, 100, 75}
  m.x_offset = 0.0
  m.y_offset = 8.0
  m.x_size = 216.0
  m.y_size = 300.0
  m.y_offset_calib_white = 1.0
  m.y_size_calib_mm = 3.0
  m.x_offset_calib_black = 0.0
  m.x_size_calib_mm = 216.0694
  m.is_cis = vrai
  m.dark_calibration = vrai          && ModelFlag::DARK_CALIBRATION
  m.shading_repark = vrai            && ModelFlag::SHADING_REPARK
  m.custom_gamma = vrai              && ModelFlag::CUSTOM_GAMMA
  m.search_lines = 400
  m.base_ydpi = 4800                 && moteur
  m.mm_par_pouce = 25.4
retourner m

&& Profils du moteur : pente (vitesse initiale, vitesse maximale, pas),
&& type de pas (0 entier, 1 demi, 2 quart, 3 huitième), exposition maximale.
fonction LIDE120_MOTEUR()
  locale p = {}
  inserer(p, {pente = PENTE_DEPUIS_PAS(62496, 864, 127), pas = 0, exposition_max = 4608})
  inserer(p, {pente = PENTE_DEPUIS_PAS(62496, 1338, 63), pas = 1, exposition_max = 5360})
  inserer(p, {pente = PENTE_DEPUIS_PAS(62464, 2632, 3), pas = 2, exposition_max = 10528})
  inserer(p, {pente = PENTE_DEPUIS_PAS(62592, 10432, 5), pas = 2, exposition_max = 20864})
retourner p

&& Registres du capteur communs à toutes les résolutions.
fonction LIDE120_REGS_COMMUNS()
retourner {{0x17, 0x04}, {0x18, 0x00}, {0x19, 0x01}, {0x1a, 0x30}, {0x1b, 0x00}, {0x1c, 0x02}, ;
           {0x1d, 0x00}, {0x20, 0x02}, {0x52, 0x04}, {0x53, 0x06}, {0x54, 0x00}, {0x55, 0x02}, ;
           {0x56, 0x04}, {0x57, 0x04}, {0x58, 0x04}, {0x59, 0x04}, {0x5a, 0x3a}, {0x5b, 0x00}, ;
           {0x5c, 0x00}, {0x61, 0x20}, {0x71, 0x1f}, {0x72, 0x08}, {0x73, 0x0a}, {0x74, 0x00}, ;
           {0x75, 0x00}, {0x76, 0x0f}, {0x77, 0x00}, {0x78, 0x00}, {0x79, 0x00}, {0x7a, 0x00}, ;
           {0x7b, 0x00}, {0x7c, 0x55}, {0x88, 0x00}, {0x89, 0x5e}, {0x93, 0x00}, {0x98, 0x21}}

&& Réglages du capteur CIS par résolution (CustomSensorSettings de SANE) :
&& résolution, résolution optique, dpihw, dpiset, résolution d'étalonnage,
&& période de ligne, exposition R G B, rapport de pixels, facteur
&& d'ombrage, puis les registres qui varient : 0x16, 0x70, SEGCNT, TG0CNT.
fonction LIDE120_CAPTEURS()
  locale lignes = { ;
    {75,   1200,  600,  150,  300,  4608, 1244, 1294, 1144, 1, 4, 4, 0x15, 0x00, 0x09f8, 0x0070}, ;
    {100,  1200,  600,  200,  300,  4608, 1244, 1294, 1144, 1, 4, 3, 0x15, 0x00, 0x09f8, 0x0070}, ;
    {150,  1200,  600,  300,  300,  4608, 1244, 1294, 1144, 1, 4, 2, 0x15, 0x00, 0x09f8, 0x0070}, ;
    {300,  1200,  600,  600,  300,  4608, 1244, 1294, 1144, 1, 4, 1, 0x15, 0x00, 0x09f8, 0x0070}, ;
    {600,  2400,  600,  600,  600,  5360, 2394, 2444, 2144, 1, 4, 1, 0x11, 0x1f, 0x13f0, 0x008b}, ;
    {1200, 2400, 1200, 1200, 1200, 10528, 4694, 4644, 4094, 1, 2, 1, 0x15, 0x1f, 0x27e0, 0x00c0}, ;
    {2400, 2400, 2400, 2400, 2400, 20864, 8944, 8144, 7994, 1, 1, 1, 0x11, 0x00, 0x4fc0, 0x012a}}
  locale capteurs = {}
  pour chaque l dans lignes
    pour chaque canaux dans {1, 3}
      locale c = {}
      c.resolution = l[1]
      c.full_resolution = 2400
      c.optical_resolution = l[2]
      c.register_dpihw = l[3]
      c.register_dpiset = l[4]
      c.shading_resolution = l[5]
      c.exposure_lperiod = l[6]
      c.exposure = {r = l[7], g = l[8], b = l[9]}
      c.ratio_mul = l[10]
      c.ratio_div = l[11]
      c.shading_factor = l[12]
      c.black_pixels = 87
      c.dummy_pixel = 16
      c.fau_gain_white_ref = 210
      c.gain_white_ref = 200
      c.gamma = {2.2, 2.2, 2.2}
      c.segment_order = {}
      c.output_pixel_offset = 0
      c.shading_pixel_offset = 0
      c.canaux = canaux
      locale regs = {}
      inserer(regs, {0x16, l[13]})
      pour chaque x dans LIDE120_REGS_COMMUNS()
        inserer(regs, x)
      suivant
      inserer(regs, {0x70, l[14]})
      inserer(regs, {0x94, DECALD(l[15], 8)})
      inserer(regs, {0x95, ET(l[15], 0xff)})
      inserer(regs, {0x96, DECALD(l[16], 8)})
      inserer(regs, {0x97, ET(l[16], 0xff)})
      inserer(regs, {0x0c, sisinon(canaux = 1, 0x10, 0x12)})
      c.custom_regs = regs
      c.indice = #capteurs + 1
      inserer(capteurs, c)
    suivant
  suivant
retourner capteurs

&& Frontal analogique (type TI, « WOLFSON_GL124 » dans SANE) :
&& registres 0x01..0x03 et 0x24..0x26 (écrits aux adresses 0x05..0x07).
fonction LIDE120_FRONTAL()
retourner {r00 = 0x80, r01 = 0xa3, r02 = 0x2b, r03 = 0x4c, r24 = 0x00, r25 = 0xca, r26 = 0x95}

&& GPIO au repos : registres 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x38
fonction LIDE120_GPIO()
retourner {{0x31, 0x9f}, {0x32, 0x53}, {0x33, 0x01}, {0x34, 0x80}, {0x35, 0x5f}, {0x36, 0x01}, {0x38, 0x00}}

&& Organisation de la mémoire interne (tables_memory_layout.cpp)
fonction LIDE120_MEMOIRE()
retourner {{0xd0, 0x0a}, {0xd1, 0x15}, {0xd2, 0x20}, ;
           {0xe0, 0x00}, {0xe1, 0xac}, {0xe2, 0x08}, {0xe3, 0x55}, ;
           {0xe4, 0x08}, {0xe5, 0x56}, {0xe6, 0x0f}, {0xe7, 0xff}, ;
           {0xe8, 0x00}, {0xe9, 0xac}, {0xea, 0x08}, {0xeb, 0x55}, ;
           {0xec, 0x08}, {0xed, 0x56}, {0xee, 0x0f}, {0xef, 0xff}, ;
           {0xf0, 0x00}, {0xf1, 0xac}, {0xf2, 0x08}, {0xf3, 0x55}, ;
           {0xf4, 0x08}, {0xf5, 0x56}, {0xf6, 0x0f}, {0xf7, 0xff}}

&& Boutons de la face avant (registre 0x31, actifs à 0)
fonction LIDE120_BOUTONS(r31)
  locale b = {}
  b.numeriser = ET(r31, 0x01) = 0
  b.copier = ET(r31, 0x02) = 0
  b.courriel = ET(r31, 0x04) = 0
  b.fichier = ET(r31, 0x08) = 0
retourner b
