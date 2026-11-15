// Exécute le pilote genesys de SANE en mode test pour le LiDE 120 et
// journalise les écritures (GENESYS_TRACE).
#define DEBUG_DECLARE_ONLY
#include "backend/genesys/device.h"
#include "backend/genesys/genesys.h"
#include "backend/genesys/test_settings.h"
#include "backend/genesys/test_scanner_interface.h"
#include "include/sane/saneopts.h"
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <stdexcept>

static int find_opt(SANE_Handle h, const char* name) {
    SANE_Int n = 0;
    sane_control_option(h, 0, SANE_ACTION_GET_VALUE, &n, nullptr);
    for (int i = 1; i < n; ++i) {
        auto* o = sane_get_option_descriptor(h, i);
        if (o && o->name && std::strcmp(o->name, name) == 0) return i;
    }
    throw std::runtime_error(std::string("option ") + name);
}
static void set_int(SANE_Handle h, const char* n, int v) { sane_control_option(h, find_opt(h, n), SANE_ACTION_SET_VALUE, &v, nullptr); }
static void set_fix(SANE_Handle h, const char* n, double v) { SANE_Int x = SANE_FIX(v); sane_control_option(h, find_opt(h, n), SANE_ACTION_SET_VALUE, &x, nullptr); }
static void set_str(SANE_Handle h, const char* n, const char* v) { sane_control_option(h, find_opt(h, n), SANE_ACTION_SET_VALUE, const_cast<char*>(v), nullptr); }

int main(int argc, char** argv) {
    // arguments : mode résolution profondeur x y l h
    const char* mode = argc > 1 ? argv[1] : "Color";
    int res = argc > 2 ? std::atoi(argv[2]) : 300;
    int depth = argc > 3 ? std::atoi(argv[3]) : 8;
    double x = argc > 4 ? std::atof(argv[4]) : 0, y = argc > 5 ? std::atof(argv[5]) : 0;
    double l = argc > 6 ? std::atof(argv[6]) : 50, hh = argc > 7 ? std::atof(argv[7]) : 50;
    genesys::enable_testing_mode(0x04a9, 0x190e, 0x0000, [](const genesys::Genesys_Device&, genesys::TestScannerInterface&, const std::string&){});
    SANE_Handle h;
    sane_init(nullptr, nullptr);
    if (sane_open(genesys::get_testing_device_name().c_str(), &h) != SANE_STATUS_GOOD) { std::puts("open failed"); return 1; }
    set_str(h, SANE_NAME_SCAN_MODE, mode);
    set_int(h, SANE_NAME_BIT_DEPTH, depth);
    set_int(h, SANE_NAME_SCAN_RESOLUTION, res);
    set_fix(h, SANE_NAME_SCAN_TL_X, x);
    set_fix(h, SANE_NAME_SCAN_TL_Y, y);
    set_fix(h, SANE_NAME_SCAN_BR_X, x + l);
    set_fix(h, SANE_NAME_SCAN_BR_Y, y + hh);
    auto st = sane_start(h);
    if (st != SANE_STATUS_GOOD) { std::printf("start: %d\n", st); return 1; }
    SANE_Parameters p;
    sane_get_parameters(h, &p);
    std::printf("params: %d x %d, %d octets/ligne, profondeur %d\n", p.pixels_per_line, p.lines, p.bytes_per_line, p.depth);
    std::vector<SANE_Byte> buf(1 << 20);
    long total = (long)p.bytes_per_line * p.lines, got = 0;
    while (got < total) {
        SANE_Int n = 0;
        auto s = sane_read(h, buf.data(), (SANE_Int)std::min<long>(buf.size(), total - got), &n);
        got += n;
        if (s != SANE_STATUS_GOOD) break;
    }
    std::printf("lu %ld octets\n", got);
    sane_cancel(h);
    sane_close(h);
    sane_exit();
    return 0;
}
