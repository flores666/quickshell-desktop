// A private wlr-virtual-pointer client for native decoration input. These are
// the version-1 protocol signatures; no seat/output assignment is requested.
#include <wayland-client.h>
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static const struct wl_message pointer_requests[] = {
    {"motion", "uff", NULL}, {"motion_absolute", "uuuuu", NULL},
    {"button", "uuu", NULL}, {"axis", "uuf", NULL}, {"frame", "", NULL},
    {"axis_source", "u", NULL}, {"axis_stop", "uu", NULL},
    {"axis_discrete", "uufi", NULL}, {"destroy", "", NULL}
};
static const struct wl_interface pointer_interface = {
    "zwlr_virtual_pointer_v1", 1, 9, pointer_requests, 0, NULL
};
static const struct wl_interface *create_types[] = {&wl_seat_interface, &pointer_interface};
static const struct wl_message manager_requests[] = {
    {"create_virtual_pointer", "?on", create_types}, {"destroy", "", NULL}
};
static const struct wl_interface manager_interface = {
    "zwlr_virtual_pointer_manager_v1", 1, 2, manager_requests, 0, NULL
};
static struct wl_proxy *manager;

static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, manager_interface.name))
        manager = wl_registry_bind(registry, name, &manager_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}

int main(int argc, char **argv) {
    if (argc != 6) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 3;
    struct wl_registry *registry = wl_display_get_registry(display);
    const struct wl_registry_listener listener = {global, removed};
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) return 4;
    struct wl_proxy *pointer = wl_proxy_marshal_flags(manager, 0, &pointer_interface, 1, 0, NULL, NULL);
    if (!pointer) return 5;
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    uint32_t stamp = (uint32_t)(now.tv_sec * 1000 + now.tv_nsec / 1000000);
    wl_proxy_marshal_flags(pointer, 1, NULL, 1, 0, stamp,
        (uint32_t)atoi(argv[1]), (uint32_t)atoi(argv[2]), (uint32_t)atoi(argv[3]), (uint32_t)atoi(argv[4]));
    wl_proxy_marshal_flags(pointer, 4, NULL, 1, 0);
    wl_display_roundtrip(display);
    if (atoi(argv[5])) {
        wl_proxy_marshal_flags(pointer, 2, NULL, 1, 0, stamp, BTN_LEFT, 1U);
        wl_proxy_marshal_flags(pointer, 4, NULL, 1, 0);
        wl_display_roundtrip(display);
        wl_proxy_marshal_flags(pointer, 2, NULL, 1, 0, stamp + 1, BTN_LEFT, 0U);
        wl_proxy_marshal_flags(pointer, 4, NULL, 1, 0);
        wl_display_roundtrip(display);
    }
    wl_proxy_marshal_flags(pointer, 8, NULL, 1, WL_MARSHAL_FLAG_DESTROY);
    wl_proxy_marshal_flags(manager, 1, NULL, 1, WL_MARSHAL_FLAG_DESTROY);
    wl_registry_destroy(registry);
    wl_display_roundtrip(display);
    wl_display_disconnect(display);
    return 0;
}
