public delegate void Callback(string a, string b);

extern void register_callback(owned Callback cb);
extern void trigger_callback(string a, string b);


void main() {
    // Register a lambda from Vala
    register_callback((a,b) => {
        print("Lambda called with value: %s %s\n", a,b);
    });
    
    // Call from C code
    trigger_callback("vem", "høj");
}