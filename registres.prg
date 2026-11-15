&& =====================================================================
&& registres.prg - jeu de registres du GL124 et opérations sur les bits
&& ---------------------------------------------------------------------
&& Un jeu de registres garde les adresses dans l'ordre croissant (c'est
&& l'ordre dans lequel ils sont écrits dans le circuit) et leur valeur.
&& Lire ou modifier un registre absent du jeu est une erreur, comme dans
&& SANE : cela révèle une faute de programmation plutôt que de l'ignorer.
&& =====================================================================

fonction ET(a, b)
retourner binaire.et(a, b)

fonction OU(a, b)
retourner binaire.ou(a, b)

fonction NON8(a)
retourner binaire.non(a, 8)

fonction DECALG(a, n)
retourner binaire.decaler(a, n)

fonction DECALD(a, n)
retourner binaire.decaler(a, -n)

&& arrondi à la précision d'un « float » C (32 bits), pour reproduire
&& exactement les calculs de SANE (tables gamma et pentes du moteur)
fonction F32(x)
retourner binaire.decoder("<f", binaire.coder("<f", x))[1]

&& division entière (C, opérandes positifs)
fonction DIVE(a, b)
retourner entier(a / b)

fonction HEX2(v)
retourner "0x" + binaire.hex(binaire.depuisoctets({ET(v, 0xff)}))

fonction HEX4(v)
retourner "0x" + binaire.hex(binaire.depuisoctets({ET(DECALD(v, 8), 0xff), ET(v, 0xff)}))

fonction REGS_NOUVEAU()
retourner {adresses = {}, val = {}}

fonction REGS_COPIE(r)
  locale c = REGS_NOUVEAU()
  pour chaque a dans r.adresses
    inserer(c.adresses, a)
    c.val[a] = r.val[a]
  suivant
retourner c

fonction REGS_A(r, a)
retourner r.val[a] <> nul

procedure REGS_INIT(r, a, v)
  si r.val[a] = nul
    locale i = #r.adresses + 1
    tantque i > 1 et r.adresses[i - 1] > a
      i -= 1
    fintantque
    inserer(r.adresses, a, i)
  finsi
  r.val[a] = ET(v, 0xff)
retourner

procedure REGS_RETIRER(r, a)
  si r.val[a] = nul
    retourner
  finsi
  r.val[a] = nul
  pour i = 1 a #r.adresses
    si r.adresses[i] = a
      retirer(r.adresses, i)
      sortir
    finsi
  suivant
retourner

fonction REGS_GET8(r, a)
  locale v = r.val[a]
  si v = nul
    erreur "registre " + HEX4(a) + " absent du jeu"
  finsi
retourner v

procedure REGS_SET8(r, a, v)
  si r.val[a] = nul
    erreur "registre " + HEX4(a) + " absent du jeu"
  finsi
  r.val[a] = ET(v, 0xff)
retourner

procedure REGS_SET16(r, a, v)
  REGS_SET8(r, a, DECALD(v, 8))
  REGS_SET8(r, a + 1, v)
retourner

procedure REGS_SET24(r, a, v)
  REGS_SET8(r, a, DECALD(v, 16))
  REGS_SET8(r, a + 1, DECALD(v, 8))
  REGS_SET8(r, a + 2, v)
retourner

fonction REGS_GET16(r, a)
retourner REGS_GET8(r, a) * 256 + REGS_GET8(r, a + 1)

fonction REGS_GET24(r, a)
retourner REGS_GET8(r, a) * 65536 + REGS_GET8(r, a + 1) * 256 + REGS_GET8(r, a + 2)

&& bits du masque remplacés par ceux de v
procedure REGS_SET8_MASQUE(r, a, v, masque)
  REGS_SET8(r, a, binaire.masquer(REGS_GET8(r, a), v, masque))
retourner

procedure REGS_ALLUMER(r, a, masque)
  REGS_SET8(r, a, OU(REGS_GET8(r, a), masque))
retourner

procedure REGS_ETEINDRE(r, a, masque)
  REGS_SET8(r, a, ET(REGS_GET8(r, a), NON8(masque)))
retourner

&& description lisible (journal, diagnostic)
fonction REGS_TEXTE(r)
  locale l = {}
  pour chaque a dans r.adresses
    inserer(l, droite(HEX4(a), 3) + "=" + droite(HEX2(r.val[a]), 2))
  suivant
retourner joindre(l, " ")
