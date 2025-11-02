#include <stdio.h>
#include "seat.h"

struct wl_pointer *pointer;
struct wl_seat *seat;
dk_mouse_info mouse_info = {};

void pointer_motion(
    void *data, 
    struct wl_pointer *pointer,
    uint32_t time, 
    wl_fixed_t surface_x,
    wl_fixed_t surface_y) {
    
    dk_mouse_info *state = data;
    state->mouse_x = wl_fixed_to_double(surface_x);
    state->mouse_y = wl_fixed_to_double(surface_y);
}

void pointer_button(void *data, struct wl_pointer *pointer, uint32_t serial,
                          uint32_t time, uint32_t button, uint32_t button_state) {
    dk_mouse_info *state = data;
    
    if (button_state == WL_POINTER_BUTTON_STATE_PRESSED) {
        state->mouse_buttons |= (1 << button);
        printf("Button %u pressed at %.1f, %.1f\n", button, state->mouse_x, state->mouse_y);
    } else {
        state->mouse_buttons &= ~(1 << button);
        printf("Button %u released\n", button);
    }
}

void pointer_enter(void *data, struct wl_pointer *wl_pointer,
                         uint32_t serial, struct wl_surface *surface,
                         wl_fixed_t surface_x, wl_fixed_t surface_y) {
    dk_mouse_info *state = data;
    state->mouse_x = wl_fixed_to_double(surface_x);
    state->mouse_y = wl_fixed_to_double(surface_y);
    printf("Pointer entered at %.1f, %.1f\n", state->mouse_x, state->mouse_y);
}

void pointer_leave(void *data, struct wl_pointer *wl_pointer,
                         uint32_t serial, struct wl_surface *surface) {
    printf("Pointer left\n");
}


void pointer_axis(void *data, struct wl_pointer *wl_pointer,
                        uint32_t time, uint32_t axis, wl_fixed_t value) {
    // Scroll events - can be empty for now
}

void pointer_frame(void *data, struct wl_pointer *wl_pointer) {
    // Frame complete - can be empty
}


// --- Seat Event Handlers ---
void seat_capabilities(void *data, struct wl_seat *seat, uint32_t capabilities) {
    dk_mouse_info *state = data;
    
    if (capabilities & WL_SEAT_CAPABILITY_POINTER) {
        if (!pointer) {
            pointer = wl_seat_get_pointer(seat);
            wl_pointer_add_listener(pointer, &pointer_listener, state);
            printf("Pointer device available\n");
        }
    } else {
        if (pointer) {
            wl_pointer_destroy(pointer);
            pointer = NULL;
            printf("Pointer device removed\n");
        }
    }
   /*  
    // You can also check for keyboard and touch here
    if (capabilities & WL_SEAT_CAPABILITY_KEYBOARD) {
        printf("Keyboard available\n");
    }
    if (capabilities & WL_SEAT_CAPABILITY_TOUCH) {
        printf("Touch available\n");
    } */
}

void seat_name(void *data, struct wl_seat *seat, const char *name) {
    printf("Seat name: %s\n", name);
}

dk_mouse_info *seat_mouse_info(){
    return &mouse_info;
}