#include "hover.h"
#include <stdlib.h>

static int inside(HitBox *o, int px, int py) {
    return (px >= o->x && px <= o->x + o->w &&
            py >= o->y && py <= o->y + o->h);
}

void hit_init(HitRegistry *r, int capacity) {
    r->objs = malloc(sizeof(HitBox)*capacity);
    r->count = 0;
    r->capacity = capacity;
}

void hit_add(HitRegistry *r, int x, int y, int w, int h, bool *hover) {
    if (r->count >= r->capacity)
        return; // full

    HitBox *o = &r->objs[r->count++];
    o->x = x;
    o->y = y;
    o->w = w;
    o->h = h;
    o->hover = hover;
}

int hit_query(HitRegistry *r, int px, int py) {
    int hit_any = 0;

    // Reset all hover flags
    for (int i = 0; i < r->count; i++) {
        if (r->objs[i].hover)
            *(r->objs[i].hover) = false;
    }

    // Find the first that matches
    for (int i = 0; i < r->count; i++) {
        HitBox *o = &r->objs[i];
        if (inside(o, px, py)) {
            if (o->hover)
                *(o->hover) = true;
            hit_any = 1;
            break; // stop after first match
        }
    }

    return hit_any;
}
