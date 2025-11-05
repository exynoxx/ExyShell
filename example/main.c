#include <stdbool.h>
#include <GLES2/gl2.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#include "../liblayershell/liblayershell.h"

#include "../src/draw.h"
#include "../src/texture.h"

int main() {

    int width = 1920;  // typical screen width, adjust as needed
    int height = 50;

    init_layer_shell("panel", width, height, BOTTOM);
    display = get_wl_display();
    dk_mouse_info *mouse_info = seat_mouse_info();
    toplevel_print_all();

    dk_context ctx;
    dk_init(&ctx, width, height);
    dk_set_bg_color(&ctx, 0.0f, 0.0f, 0.0f, 0.0f);

    const char *fedora = "/usr/share/icons/hicolor/32x32/apps/fedora-logo-icon.png";

    Image img = dk_image_load(fedora);
    GLuint icon_tex = dk_texture_upload(img);
    

    // --- Render loop ---
    while (wl_display_dispatch(display) != -1) {

        //printf("Mouse: %f, %f\n", mouse_info->mouse_x, mouse_info->mouse_y);

        dk_begin_frame(&ctx);
        
        dk_set_color(&ctx, 1.0f, 1.0f, 1.0f, 0.1f);
        dk_draw_rect(&ctx, 0, 0, 50, height);

        dk_set_color(&ctx, 1.0f, 1.0f, 1.0f, 1.0f);
        dk_draw_texture(&ctx, icon_tex, 10, 9, 32, 32);
        dk_draw_texture(&ctx, icon_tex, 60, 9, 32, 32);
        dk_draw_texture(&ctx, icon_tex, 110, 9, 32, 32);

        dk_end_frame();
        eglSwapBuffers(egl_display, egl_surface);
    }

    // --- Cleanup ---
    destroy_layer_shell();
    return 0;
}