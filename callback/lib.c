#include <glib.h>

typedef void (*Callback)(char *a, char *b);

Callback stored_callback = NULL;

void register_callback(Callback cb) {
    stored_callback = cb;
}

void trigger_callback(char *a, char *b) {
    if (stored_callback != NULL) {
        stored_callback(a, b);
    }
}
