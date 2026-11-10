// A private virtual keyboard for the compositor's real Super+drag binding.
#define _GNU_SOURCE
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include <linux/input-event-codes.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static const struct wl_message keyboard_requests[] = {
    {"keymap", "uhu", NULL}, {"key", "uuu", NULL},
    {"modifiers", "uuuu", NULL}, {"destroy", "", NULL}
};
static const struct wl_interface keyboard_interface = {
    "zwp_virtual_keyboard_v1", 1, 4, keyboard_requests, 0, NULL
};
static const struct wl_interface *create_types[] = {&wl_seat_interface, &keyboard_interface};
static const struct wl_message manager_requests[] = {{"create_virtual_keyboard", "on", create_types}};
static const struct wl_interface manager_interface = {
    "zwp_virtual_keyboard_manager_v1", 1, 1, manager_requests, 0, NULL
};
static struct wl_proxy *manager;
static struct wl_seat *seat;

static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, manager_interface.name)) manager = wl_registry_bind(registry, name, &manager_interface, 1);
    if (!strcmp(interface, "wl_seat")) seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 2;
    struct wl_registry *registry = wl_display_get_registry(display);
    const struct wl_registry_listener listener = {global, removed};
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager || !seat) return 3;
    struct wl_proxy *keyboard = wl_proxy_marshal_flags(manager, 0, &keyboard_interface, 1, 0, seat, NULL);
    struct xkb_context *context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_keymap *keymap = context ? xkb_keymap_new_from_names(context, NULL, XKB_KEYMAP_COMPILE_NO_FLAGS) : NULL;
    if (!keyboard || !keymap) return 4;
    char *data = xkb_keymap_get_as_string(keymap, XKB_KEYMAP_FORMAT_TEXT_V1);
    if (!data) return 5;
    size_t size = strlen(data) + 1;
    int fd = memfd_create("window-test-keymap", MFD_CLOEXEC);
    if (fd < 0 || write(fd, data, size) != (ssize_t)size) return 6;
    wl_proxy_marshal_flags(keyboard, 0, NULL, 1, 0, 1U, fd, (uint32_t)size);
    if (wl_display_roundtrip(display) < 0) return 7;
    close(fd);
    xkb_mod_index_t modifier = xkb_keymap_mod_get_index(keymap, XKB_MOD_NAME_LOGO);
    if (modifier == XKB_MOD_INVALID || modifier >= 32) return 8;
    int pressed;
    while (scanf("%d", &pressed) == 1) {
        if (pressed != 0 && pressed != 1) return 9;
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        uint32_t stamp = (uint32_t)(now.tv_sec * 1000 + now.tv_nsec / 1000000);
        wl_proxy_marshal_flags(keyboard, 1, NULL, 1, 0, stamp, KEY_LEFTMETA, (uint32_t)pressed);
        wl_proxy_marshal_flags(keyboard, 2, NULL, 1, 0, pressed ? 1U << modifier : 0U, 0U, 0U, 0U);
        if (wl_display_roundtrip(display) < 0) return 10;
        puts("ok"); fflush(stdout);
    }
    wl_proxy_marshal_flags(keyboard, 2, NULL, 1, 0, 0U, 0U, 0U, 0U);
    wl_proxy_marshal_flags(keyboard, 3, NULL, 1, WL_MARSHAL_FLAG_DESTROY);
    wl_display_roundtrip(display);
    free(data); xkb_keymap_unref(keymap); xkb_context_unref(context);
    wl_display_disconnect(display);
    return 0;
}
