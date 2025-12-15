#ifndef OUTPUT_H
#define OUTPUT_H

typedef struct surface_size_t {
    int width;
    int height;
} surface_size_t;

void output_init(void);
void output_destroy();
surface_size_t *get_screen_size();

#endif