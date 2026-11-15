# Compare deux journaux d'écritures (SANE instrumenté et portage Lexis+) bloc
# par bloc : registres écrits et tables de pente envoyées avant chaque point
# de contrôle (move_back_home, led_calibration, start_scan...).
#   python3 comparer.py sane.txt lexis.txt [registres,à,ignorer]
import sys
def blocks(path):
    """Blocs de programmation : tables de pente, registres, puis le point de contrôle (# nom).
    Les premières écritures (amorçage de la puce) forment le bloc « amorcage »."""
    lines = [l.split() for l in open(path) if l.strip()]
    out = []
    cur = {'pentes': [], 'regs': {}, 'autres': []}
    vu_amorcage = False
    for l in lines:
        if l[0] == 'W' and l[1] == '0f7' and not vu_amorcage:
            # fin de l'amorçage (organisation de la mémoire) : bloc à part
            cur['regs'][l[1]] = l[2]
            cur['nom'] = 'amorcage'
            out.append(cur)
            cur = {'pentes': [], 'regs': {}, 'autres': []}
            vu_amorcage = True
            continue
        if l[0] == '#':
            cur['nom'] = l[1]
            out.append(cur)
            cur = {'pentes': [], 'regs': {}, 'autres': []}
        elif l[0] == 'AHB' and 0x10000000 <= int(l[1], 16) < 0x10014000 and int(l[1], 16) % 0x4000 == 0:
            cur['pentes'].append((l[1], l[2], l[3]))
        elif l[0] == 'W':
            cur['regs'][l[1]] = l[2]
        else:
            cur['autres'].append(' '.join(l))
    return out
a = blocks(sys.argv[1]); b = blocks(sys.argv[2])
masque = set(sys.argv[3].split(',')) if len(sys.argv) > 3 and sys.argv[3] else set()
print("SANE :", ' '.join(x['nom'] for x in a)); print("Lexis:", ' '.join(x['nom'] for x in b))
ib = 0
total = 0
for x in a:
    while ib < len(b) and b[ib]['nom'] != x['nom'] and x['nom'] != 'move_back_home':
        print("  (Lexis en plus :", b[ib]['nom'], ")"); ib += 1
    if ib >= len(b) or b[ib]['nom'] != x['nom']:
        print(f"  {x['nom']:28} : absent côté Lexis (le simulateur est déjà à la base)"); continue
    y = b[ib]; ib += 1
    # registres du bloc : ceux écrits depuis le point de contrôle précédent
    ks = sorted(set(x['regs']) | set(y['regs']))
    d = [(k, x['regs'].get(k), y['regs'].get(k)) for k in ks if x['regs'].get(k) != y['regs'].get(k) and k not in masque]
    p = "pentes identiques" if x['pentes'] == y['pentes'] else f"PENTES {x['pentes'][:1]} / {y['pentes'][:1]}"
    total += len(d)
    print(f"  {x['nom']:28} : {len(x['regs']):3} / {len(y['regs']):3} registres, {p}, {len(d)} écart(s) " + ' '.join(f"{k}:{u}/{v}" for k, u, v in d))
print("écarts au total :", total)
