#!/bin/sh
# Compare la programmation du LiDE 120 par SANE et par le portage Lexis+.
#   sh comparer.sh [mode résolution profondeur x y largeur hauteur]
#   ex. : sh comparer.sh Color 300 8 20 30 80 50
ICI=$(cd "$(dirname "$0")" && pwd)
LEXIS=${WDLEXISRT:-wdlexisrt}
set -- ${1:-Color} ${2:-300} ${3:-8} ${4:-20} ${5:-30} ${6:-80} ${7:-50}
N="$1_$2_$3"
GENESYS_TRACE="$ICI/sane_$N.txt" "$ICI/sane_lide120" "$@"
"$LEXIS" "$ICI/../principal.prg" --comparer "$@" "$ICI/lexis_$N.txt"
"$LEXIS" "$ICI/../principal.prg" --comparer "$@" "$ICI/zero_$N.txt" zero
echo "--- registres et tables de pente (expositions exclues : elles dépendent de l'étalonnage)"
python3 "$ICI/comparer.py" "$ICI/sane_$N.txt" "$ICI/lexis_$N.txt" 08a,08b,08c,08d,08e,08f,090,091,092
echo "--- ombrage (données nulles, comme l'interface de test de SANE) et gamma"
grep '^AHB 1001\|^AHB 1002\|^AHB 1004' "$ICI/zero_$N.txt" | sort -u > "$ICI/.a"
grep '^AHB 1001\|^AHB 1002\|^AHB 1004' "$ICI/sane_$N.txt" | sort -u > "$ICI/.b"
cmp -s "$ICI/.a" "$ICI/.b" && echo "ombrage : identique" || echo "ombrage : DIFFÉRENT"
grep '^AHB 0100' "$ICI/lexis_$N.txt" | sort -u > "$ICI/.a"
grep '^AHB 0100' "$ICI/sane_$N.txt" | sort -u > "$ICI/.b"
cmp -s "$ICI/.a" "$ICI/.b" && echo "gamma : identique" || echo "gamma : DIFFÉRENT"
rm -f "$ICI/.a" "$ICI/.b"
