#ifndef SEAT_H
#define SEAT_H

#include <wayland-client.h>
#include "wayland/wlr-layer-shell-unstable-v1-client-protocol.h"

typedef struct dk_mouse_info{
    double mouse_x;
    double mouse_y;
    uint32_t mouse_buttons;  // Bitmask of pressed buttons
} dk_mouse_info;

void pointer_motion(
    void *data, 
    struct wl_pointer *pointer,
    uint32_t time, 
    wl_fixed_t surface_x,
    wl_fixed_t surface_y);

void pointer_button(
    void *data,
    struct wl_pointer *pointer, 
    uint32_t serial, 
    uint32_t time, 
    uint32_t button, 
    uint32_t button_state);
    
void pointer_enter(void *data, struct wl_pointer *wl_pointer,uint32_t serial, struct wl_surface *surface,wl_fixed_t surface_x, wl_fixed_t surface_y);
void pointer_leave(void *data, struct wl_pointer *wl_pointer,uint32_t serial, struct wl_surface *surface);
void pointer_axis(void *data, struct wl_pointer *wl_pointer,uint32_t time, uint32_t axis, wl_fixed_t value);
void pointer_frame(void *data, struct wl_pointer *wl_pointer);

void seat_capabilities(void *data, struct wl_seat *seat, uint32_t capabilities);
void seat_name(void *data, struct wl_seat *seat, const char *name);
dk_mouse_info *seat_mouse_info();

static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter,
    .leave = pointer_leave,
    .axis = pointer_axis,
    .frame = pointer_frame,
    .motion = pointer_motion,
    .button = pointer_button
};

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

#endif