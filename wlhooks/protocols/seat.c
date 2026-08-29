#include "seat.h"
#include "registry.h"

#include <wayland-client.h>

#define SEAT_MAX_VERSION 5

static struct wl_seat *seat = NULL;

// GTK owns pointer/keyboard; wlhooks attaches no input listeners of its own.
static void on_capabilities(void *data, struct wl_seat *s, uint32_t capabilities) {}
static void on_name(void *data, struct wl_seat *s, const char *name) {}

static const struct wl_seat_listener seat_listener = {
    .capabilities = on_capabilities,
    .name         = on_name,
};

static void seat_registry_handler(void *data, struct wl_registry *registry,
                                  uint32_t name, const char *interface,
                                  uint32_t version) {
    // Take only the first advertised seat; multi-seat support is out of scope.
    if (seat) return;
    uint32_t v = version > SEAT_MAX_VERSION ? SEAT_MAX_VERSION : version;
    seat = wl_registry_bind(registry, name, &wl_seat_interface, v);
    wl_seat_add_listener(seat, &seat_listener, NULL);
}

void seat_init(void) {
    registry_add_handler(wl_seat_interface.name, seat_registry_handler, NULL);
}

void seat_cleanup(void) {
    if (seat) {
        wl_seat_release(seat);
        seat = NULL;
    }
}

struct wl_seat *get_wl_seat(void) {
    return seat;
}
