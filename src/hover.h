#ifndef HOVER_H
#define HOVER_H

#include <stdbool.h>

typedef struct {
    int x, y, w, h;
    bool *hover;
} HitBox;

typedef struct {
    HitBox *objs;
    int count;
    int capacity;
} HitRegistry;

//TODO auto init on first register
void hit_init(HitRegistry *r, int capacity);
void hit_add(HitRegistry *r, int x, int y, int w, int h, bool *hit);
int hit_query(HitRegistry *r, int px, int py);

#endif
