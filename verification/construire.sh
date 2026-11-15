#!/bin/sh
# Construit le pilote genesys de SANE en « mode test » (sans scanner), avec un
# journal des écritures, pour comparer sa programmation du LiDE 120 à celle du
# portage Lexis+.
#   sh construire.sh /chemin/vers/sane-backends-1.4.0
set -e
SANE=$(cd "$1" && pwd)
ICI=$(cd "$(dirname "$0")" && pwd)
OBJ="$ICI/obj"
mkdir -p "$OBJ"
cd "$SANE"
# en-têtes produits d'habitude par configure
[ -f include/_stdint.h ] || echo '#include <stdint.h>' > include/_stdint.h
[ -f include/sane/config.h ] || cat > include/sane/config.h <<'H'
#ifndef SANE_CONFIG_H
#define SANE_CONFIG_H
#define PACKAGE "sane-backends"
#define VERSION "1.4.0"
#define PACKAGE_STRING "sane-backends 1.4.0"
#define HAVE_SYS_TIME_H 1
#define HAVE_SIGPROCMASK 1
#define HAVE_UNISTD_H 1
#define HAVE_STDINT_H 1
#define V_MAJOR 1
#define V_MINOR 4
#define PATH_SEP ':'
#define DIR_SEP "/"
#define STATEDIR "/tmp"
#define SANE_CONFIG_DIR "/tmp"
#endif
H
# journal des écritures dans l'interface de test (GENESYS_TRACE=fichier)
grep -q GENESYS_TRACE backend/genesys/test_scanner_interface.cpp || patch -p1 < "$ICI/trace.patch"
for f in backend/genesys/*.cpp; do
  g++ -std=c++17 -O1 -w -c -DBACKEND_NAME=genesys -Iinclude -I. "$f" -o "$OBJ/$(basename "$f" .cpp).o"
done
g++ -std=c++17 -O1 -w -DBACKEND_NAME=genesys -Iinclude -I. -c "$ICI/harness.cpp" -o "$OBJ/harness.o"
gcc -O1 -w -Iinclude -I. -c "$ICI/stubs.c" -o "$OBJ/stubs.o"
gcc -O1 -w -DBACKEND_NAME=genesys -Iinclude -I. -c sanei/sanei_constrain_value.c -o "$OBJ/cv.o"
gcc -O1 -w -DBACKEND_NAME=genesys -Iinclude -I. -c sanei/sanei_init_debug.c -o "$OBJ/dbg.o"
gcc -O1 -w -Iinclude -I. -c backend/sane_strstatus.c -o "$OBJ/ss.o"
g++ -o "$ICI/sane_lide120" "$OBJ"/*.o
echo "construit : $ICI/sane_lide120"
