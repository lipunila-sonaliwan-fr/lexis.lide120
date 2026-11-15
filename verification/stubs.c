#include "include/sane/config.h"
#include "include/sane/sane.h"
#include <stddef.h>
typedef void* vp;
SANE_Status sanei_configure_attach(const char* f, void* c, SANE_Status (*cb)(void*, const char*, void*), void* d) { (void)f;(void)c;(void)cb;(void)d; return SANE_STATUS_GOOD; }
void sanei_usb_init(void) {}
void sanei_usb_exit(void) {}
void sanei_usb_scan_devices(void) {}
SANE_Status sanei_usb_attach_matching_devices(const char* n, SANE_Status (*a)(const char*)) { (void)n;(void)a; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_find_devices(SANE_Int v, SANE_Int p, SANE_Status (*a)(const char*)) { (void)v;(void)p;(void)a; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_open(const char* n, SANE_Int* d) { (void)n; *d = 0; return SANE_STATUS_GOOD; }
void sanei_usb_close(SANE_Int d) { (void)d; }
SANE_Status sanei_usb_clear_halt(SANE_Int d) { (void)d; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_reset(SANE_Int d) { (void)d; return SANE_STATUS_GOOD; }
void sanei_usb_set_timeout(SANE_Int t) { (void)t; }
SANE_Status sanei_usb_control_msg(SANE_Int d, SANE_Int a, SANE_Int b, SANE_Int c, SANE_Int e, SANE_Int f, SANE_Byte* g) { (void)d;(void)a;(void)b;(void)c;(void)e;(void)f;(void)g; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_read_bulk(SANE_Int d, SANE_Byte* b, size_t* s) { (void)d;(void)b;(void)s; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_write_bulk(SANE_Int d, const SANE_Byte* b, size_t* s) { (void)d;(void)b;(void)s; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_get_vendor_product(SANE_Int d, SANE_Word* v, SANE_Word* p) { (void)d; *v = 0x04a9; *p = 0x190e; return SANE_STATUS_GOOD; }
SANE_Status sanei_usb_get_descriptor(SANE_Int d, void* desc) { (void)d;(void)desc; return SANE_STATUS_GOOD; }
SANE_Bool sanei_usb_is_replay_mode_enabled(void) { return SANE_FALSE; }
void sanei_usb_testing_record_message(SANE_String_Const m) { (void)m; }
