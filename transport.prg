&& =====================================================================
&& transport.prg - protocole USB du GL124
&& ---------------------------------------------------------------------
&& (scanner_interface_usb.cpp de SANE)
&&   registre : requête 0x04 (REQUEST_BUFFER), valeur 0x83 (écriture) ou
&&              0x8e (lecture) + 0x100 pour les registres 0x100 et plus ;
&&              une lecture renvoie la valeur suivie de 0x55.
&&   données  : en-tête de 8 octets (adresse 0x10000000, taille) par
&&              requête 0x04 / 0x82, puis lecture bulk, par blocs de 0xeff0.
&&   mémoire AHB (pentes moteur, gamma, ombrage) : en-tête adresse + taille
&&              (index 1), puis écriture bulk.
&& Le transport est un périphérique usb réel ou le simulateur.
&& =====================================================================

fonction T_USB(p)
  locale t = {genre = "usb", p = p, entree = 0x81, sortie = 0x02, simulation = faux}
  essayer
    pour chaque e dans p:points()
      si e.genre = "bulk" et e.sens = "entree"
        t.entree = e.adresse
      sinonsi e.genre = "bulk" et e.sens = "sortie"
        t.sortie = e.adresse
      finsi
    suivant
  capturer err
  finessayer
retourner t

fonction T_SIMULATION(sim)
retourner {genre = "simulation", sim = sim, simulation = vrai}

fonction T_CONTROLE(t, rt, req, v, idx, donnees)
  si t.simulation
    retourner SIM_CONTROLE(t.sim, rt, req, v, idx, donnees)
  finsi
retourner t.p:controle(rt, req, v, idx, donnees)

fonction T_LIRE(t, n)
  si t.simulation
    retourner SIM_LIRE(t.sim, n)
  finsi
retourner t.p:lire(t.entree, n, 60000)

fonction T_ECRIRE(t, donnees)
  si t.simulation
    retourner SIM_ECRIRE(t.sim, donnees)
  finsi
retourner t.p:ecrire(t.sortie, donnees, 30000)

&& --- constantes (low.h) ---
fonction RT_IN()
retourner 0xc0
fonction RT_OUT()
retourner 0x40

procedure GL_DORMIR(ms)
  globale DEV
  si DEV <> nul et DEV.tr.simulation
    retourner
  finsi
  systeme.attendre(ms / 1000)
retourner

fonction GL_LIRE_REG(adr)
  globale DEV
  locale v = 0x8e
  si adr > 0xff
    v = OU(v, 0x100)
  finsi
  locale idx = 0x22 + DECALG(ET(adr, 0xff), 8)
  locale r = T_CONTROLE(DEV.tr, RT_IN(), 0x04, v, idx, 2)
  si binaire.longueur(r) < 2 ou binaire.octet(r, 2) <> 0x55
    erreur "lecture du registre " + HEX4(adr) + " invalide (scanner débranché ?)"
  finsi
retourner binaire.octet(r, 1)

&& Journal des écritures (comparaison avec le pilote SANE en mode test) :
&& DEV.journal_ecritures = {} active l'enregistrement.
procedure NOTER_ECRITURE(ligne)
  globale DEV
  si DEV.journal_ecritures <> nul et non DEV.dans_frontal
    inserer(DEV.journal_ecritures, ligne)
  finsi
retourner

fonction HEXN(v, n)
  locale octets = {}
  pour i = n - 1 a 0 pas -1
    inserer(octets, ET(DECALD(v, 8 * i), 0xff))
  suivant
retourner binaire.hex(binaire.depuisoctets(octets))

procedure GL_ECRIRE_REG(adr, val)
  globale DEV
  si DEV.journal_ecritures <> nul
    NOTER_ECRITURE("W " + droite(HEXN(adr, 2), 3) + " " + HEXN(val, 1))
  finsi
  locale v = 0x83
  si adr > 0xff
    v = OU(v, 0x100)
  finsi
  T_CONTROLE(DEV.tr, RT_OUT(), 0x04, v, 0, binaire.depuisoctets({ET(adr, 0xff), ET(val, 0xff)}))
retourner

procedure GL_ECRIRE_REGS(r)
  pour chaque a dans r.adresses
    GL_ECRIRE_REG(a, r.val[a])
  suivant
retourner

&& lecture-modification-écriture
procedure GL_REG_BITS(adr, v, masque)
  GL_ECRIRE_REG(adr, binaire.masquer(GL_LIRE_REG(adr), v, masque))
retourner

procedure GL_ECRIRE_8C(idx, val)
  globale DEV
  si DEV.journal_ecritures <> nul
    NOTER_ECRITURE("8C " + HEXN(idx, 1) + " " + HEXN(val, 1))
  finsi
  T_CONTROLE(DEV.tr, RT_OUT(), 0x0c, 0x8c, idx, binaire.depuisoctets({val}))
retourner

fonction LE32(x)
retourner binaire.coder("<I", x)

&& écriture en mémoire AHB
procedure GL_AHB(adr, donnees)
  globale DEV
  locale n = binaire.longueur(donnees)
  si DEV.journal_ecritures <> nul
    NOTER_ECRITURE("AHB " + HEXN(adr, 4) + " " + n + " " + HEXN(binaire.crc32(donnees), 4))
  finsi
  T_CONTROLE(DEV.tr, RT_OUT(), 0x04, 0x82, 0x01, LE32(adr) + LE32(n))
  locale fait = 0
  tantque fait < n
    locale bloc = min(n - fait, 0xeff0)
    T_ECRIRE(DEV.tr, binaire.extraire(donnees, fait + 1, bloc))
    fait += bloc
  fintantque
retourner

&& lecture de n octets de données image (bulk_read_data du GL124) : un
&& en-tête (adresse 0x10000000, taille) avant chaque bloc d'au plus 0xeff0
&& octets ; une lecture incomplète est suivie d'un nouvel en-tête pour le reste.
fonction GL_LIRE_DONNEES(n)
  globale DEV
  locale morceaux = {}
  locale reste = n
  locale vides = 0
  tantque reste > 0
    locale bloc = min(reste, 0xeff0)
    T_CONTROLE(DEV.tr, RT_OUT(), 0x04, 0x82, 0x00, binaire.depuisoctets({0, 0, 0, 0x10}) + LE32(bloc))
    locale d = T_LIRE(DEV.tr, bloc)
    locale recu = binaire.longueur(d)
    si recu = 0
      vides += 1
      si vides > 3
        erreur "lecture des données : le scanner n'envoie plus rien (" + (n - reste) + " / " + n + " octets)"
      finsi
    sinon
      vides = 0
      inserer(morceaux, d)
      reste -= recu
    finsi
  fintantque
retourner joindre(morceaux, "")

&& registre du frontal analogique (0x51 adresse, 0x5d 0x5e valeur)
procedure GL_FE_ECRIRE(adr, v)
  globale DEV
  si DEV.journal_ecritures <> nul
    NOTER_ECRITURE("FE " + HEXN(adr, 1) + " " + HEXN(v, 2))
  finsi
  DEV.dans_frontal = vrai
  GL_ECRIRE_REG(0x51, adr)
  GL_ECRIRE_REG(0x5d, ET(DIVE(v, 256), 0xff))
  GL_ECRIRE_REG(0x5e, ET(v, 0xff))
  DEV.dans_frontal = faux
retourner
