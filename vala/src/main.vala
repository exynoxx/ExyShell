using GLES2;

[CCode (cname = "wl_init")]
extern void wl_init();

[CCode (cname = "layer_shell_init")]
extern void layer_shell_init();

[CCode (cname = "egl_init")]
extern void egl_init();

[CCode (cname = "dispose")]
extern void dispose();

[CCode (cname = "egl_surface")]
extern void *egl_surface();

[CCode (cname = "egl_display")]
extern void *egl_display();

public class LayerShellPanel : Object {

    public LayerShellPanel () {
        wl_init();
        layer_shell_init();
        egl_init();
    }

    public void render_loop () {
        var program = create_program();
        if (program == 0) {
            stderr.printf("Failed to create shader program\n");
            return;
        }

        GLES2.glUseProgram(program);
        
        float[] vertices = { 0.0f, 0.5f, -0.5f, -0.5f, 0.5f, -0.5f };
        int pos_loc = GLES2.glGetAttribLocation(program, "pos");
        
        GLES2.glVertexAttribPointer(pos_loc, 2, GLES2.GL_FLOAT, false, 0, vertices);
        GLES2.glEnableVertexAttribArray(pos_loc);

        // Main render loop
        while (display.dispatch() != -1) {
            GLES2.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
            GLES2.glClear(GLES2.GL_COLOR_BUFFER_BIT);
            GLES2.glDrawArrays(GLES2.GL_TRIANGLES, 0, 3);
            EGL.eglSwapBuffers(egl_display, egl_surface);
        }

        GLES2.glDeleteProgram(program);
        dispose();
    }

    private int create_program () {
        string vertex_src = """
            attribute vec2 pos;
            void main() {
                gl_Position = vec4(pos, 0.0, 1.0);
            }
        """;

        string fragment_src = """
            precision mediump float;
            void main() {
                gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
            }
        """;

        int vertex_shader = GLES2.glCreateShader(GLES2.GL_VERTEX_SHADER);
        GLES2.glShaderSource(vertex_shader, 1, { vertex_src }, null);
        GLES2.glCompileShader(vertex_shader);

        GLint compiled;
        GLES2.glGetShaderiv(vertex_shader, GLES2.GL_COMPILE_STATUS, out compiled);
        if (compiled == 0) {
            stderr.printf("Vertex shader compilation failed\n");
            GLES2.glDeleteShader(vertex_shader);
            return 0;
        }

        int fragment_shader = GLES2.glCreateShader(GLES2.GL_FRAGMENT_SHADER);
        GLES2.glShaderSource(fragment_shader, 1, { fragment_src }, null);
        GLES2.glCompileShader(fragment_shader);

        GLES2.glGetShaderiv(fragment_shader, GLES2.GL_COMPILE_STATUS, out compiled);
        if (compiled == 0) {
            stderr.printf("Fragment shader compilation failed\n");
            GLES2.glDeleteShader(fragment_shader);
            GLES2.glDeleteShader(vertex_shader);
            return 0;
        }

        int program = GLES2.glCreateProgram();
        GLES2.glAttachShader(program, vertex_shader);
        GLES2.glAttachShader(program, fragment_shader);
        GLES2.glLinkProgram(program);

        GLint linked;
        GLES2.glGetProgramiv(program, GLES2.GL_LINK_STATUS, out linked);
        if (linked == 0) {
            stderr.printf("Program linking failed\n");
            GLES2.glDeleteProgram(program);
            GLES2.glDeleteShader(vertex_shader);
            GLES2.glDeleteShader(fragment_shader);
            return 0;
        }

        GLES2.glDeleteShader(vertex_shader);
        GLES2.glDeleteShader(fragment_shader);

        return program;
    }

    public static int main (string[] args) {
        var panel = new LayerShellPanel();
        panel.render_loop();
        return 0;
    }
}

/*  public class LayerShellPanel : Object {
    Display display;
    Registry registry;
    Compositor compositor;
    LayerShellV1 layer_shell;
    Surface surface;
    LayerSurfaceV1 layer_surface;
    EGLDisplay egl_display;
    EGLSurface egl_surface;
    EGLContext egl_context;
    void* egl_window;

    public LayerShellPanel () {
        display = Display.connect(null);
        registry = display.get_registry();
        
        registry.global.connect((id, interface_name, version) => {
            if (interface_name == "wl_compositor") {
                compositor = (Compositor) registry.bind(id, 
                    Compositor.get_interface(), version);
            }
            else if (interface_name == "zwlr_layer_shell_v1") {
                var obj = registry.bind(id, 
                    LayerShellV1.get_interface(), version);
                layer_shell = (LayerShellV1) obj;
            }
        });
        
        display.roundtrip();
        
        if (compositor == null) {
            stderr.printf("Failed to bind compositor\n");
            return;
        }
        if (layer_shell == null) {
            stderr.printf("Failed to bind layer shell\n");
            return;
        }
    }

    public void setup_layer_surface () {
        surface = compositor.create_surface();
        if (surface == null) {
            stderr.printf("Failed to create surface\n");
            return;
        }

        layer_surface = layer_shell.get_layer_surface(
            surface, null, (uint32) LayerShellV1Layer.TOP, "triangle-panel");

        if (layer_surface == null) {
            stderr.printf("Failed to create layer surface\n");
            return;
        }

        // Set anchor: top | bottom | left | right
        layer_surface.set_anchor(
            (uint32) (LayerSurfaceV1Anchor.TOP | 
                      LayerSurfaceV1Anchor.BOTTOM |
                      LayerSurfaceV1Anchor.LEFT | 
                      LayerSurfaceV1Anchor.RIGHT)
        );
        
        layer_surface.set_size(400, 300);
        layer_surface.set_exclusive_zone(-1); // extend to edges
        layer_surface.set_keyboard_interactivity(
            (uint32) LayerSurfaceV1KeyboardInteractivity.NONE);

        // Add configure listener
        LayerSurfaceV1Listener listener = LayerSurfaceV1Listener() {
            configure = on_configure,
            closed = on_closed
        };
        layer_surface.add_listener(listener, this);

        // Commit initial state
        surface.commit();
    }

    private static void on_configure(void* data, LayerSurfaceV1 surface, 
                                     uint32 serial, uint32 width, uint32 height) {
        var self = (LayerShellPanel) data;
        self.layer_surface.ack_configure(serial);
    }

    private static void on_closed(void* data, LayerSurfaceV1 surface) {
        var self = (LayerShellPanel) data;
        self.cleanup();
    }

    public void setup_egl () {
        // Get native display from Wayland display
        void* native_display = (void*) display;
        
        egl_display = EGL.eglGetDisplay(native_display);
        if (egl_display == EGL.EGL_NO_DISPLAY) {
            stderr.printf("Failed to get EGL display\n");
            return;
        }

        EGLint major, minor;
        if (EGL.eglInitialize(egl_display, out major, out minor) == 0) {
            stderr.printf("Failed to initialize EGL\n");
            return;
        }

        EGLConfig config;
        EGLint num_configs;
        EGLint[] cfg_attribs = {
            EGL.EGL_SURFACE_TYPE, EGL.EGL_WINDOW_BIT,
            EGL.EGL_RED_SIZE, 8,
            EGL.EGL_GREEN_SIZE, 8,
            EGL.EGL_BLUE_SIZE, 8,
            EGL.EGL_ALPHA_SIZE, 8,
            EGL.EGL_RENDERABLE_TYPE, EGL.EGL_OPENGL_ES2_BIT,
            EGL.EGL_NONE
        };
        
        if (EGL.eglChooseConfig(egl_display, cfg_attribs, out config, 1, out num_configs) == 0) {
            stderr.printf("Failed to choose EGL config\n");
            return;
        }

        egl_window = EGL.wl_egl_window_create((void*)surface, 400, 300);
        if (egl_window == null) {
            stderr.printf("Failed to create EGL window\n");
            return;
        }

        EGLint[] srf_attribs = { EGL.EGL_NONE };
        egl_surface = EGL.eglCreateWindowSurface(egl_display, config, egl_window, srf_attribs);
        if (egl_surface == EGL.EGL_NO_SURFACE) {
            stderr.printf("Failed to create EGL surface\n");
            return;
        }

        EGLint[] ctx_attribs = {
            EGL.EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL.EGL_NONE
        };
        
        egl_context = EGL.eglCreateContext(egl_display, config, EGL.EGL_NO_CONTEXT, ctx_attribs);
        if (egl_context == EGL.EGL_NO_CONTEXT) {
            stderr.printf("Failed to create EGL context\n");
            return;
        }

        if (EGL.eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context) == 0) {
            stderr.printf("Failed to make EGL context current\n");
            return;
        }
    }

    public void render_loop () {
        var program = create_program();
        if (program == 0) {
            stderr.printf("Failed to create shader program\n");
            return;
        }

        GLES2.glUseProgram(program);
        
        float[] vertices = { 0.0f, 0.5f, -0.5f, -0.5f, 0.5f, -0.5f };
        int pos_loc = GLES2.glGetAttribLocation(program, "pos");
        
        GLES2.glVertexAttribPointer(pos_loc, 2, GLES2.GL_FLOAT, false, 0, vertices);
        GLES2.glEnableVertexAttribArray(pos_loc);

        // Main render loop
        while (display.dispatch() != -1) {
            GLES2.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
            GLES2.glClear(GLES2.GL_COLOR_BUFFER_BIT);
            GLES2.glDrawArrays(GLES2.GL_TRIANGLES, 0, 3);
            EGL.eglSwapBuffers(egl_display, egl_surface);
        }

        GLES2.glDeleteProgram(program);
    }

    private int create_program () {
        string vertex_src = """
            attribute vec2 pos;
            void main() {
                gl_Position = vec4(pos, 0.0, 1.0);
            }
        """;

        string fragment_src = """
            precision mediump float;
            void main() {
                gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
            }
        """;

        int vertex_shader = GLES2.glCreateShader(GLES2.GL_VERTEX_SHADER);
        GLES2.glShaderSource(vertex_shader, 1, { vertex_src }, null);
        GLES2.glCompileShader(vertex_shader);

        GLint compiled;
        GLES2.glGetShaderiv(vertex_shader, GLES2.GL_COMPILE_STATUS, out compiled);
        if (compiled == 0) {
            stderr.printf("Vertex shader compilation failed\n");
            GLES2.glDeleteShader(vertex_shader);
            return 0;
        }

        int fragment_shader = GLES2.glCreateShader(GLES2.GL_FRAGMENT_SHADER);
        GLES2.glShaderSource(fragment_shader, 1, { fragment_src }, null);
        GLES2.glCompileShader(fragment_shader);

        GLES2.glGetShaderiv(fragment_shader, GLES2.GL_COMPILE_STATUS, out compiled);
        if (compiled == 0) {
            stderr.printf("Fragment shader compilation failed\n");
            GLES2.glDeleteShader(fragment_shader);
            GLES2.glDeleteShader(vertex_shader);
            return 0;
        }

        int program = GLES2.glCreateProgram();
        GLES2.glAttachShader(program, vertex_shader);
        GLES2.glAttachShader(program, fragment_shader);
        GLES2.glLinkProgram(program);

        GLint linked;
        GLES2.glGetProgramiv(program, GLES2.GL_LINK_STATUS, out linked);
        if (linked == 0) {
            stderr.printf("Program linking failed\n");
            GLES2.glDeleteProgram(program);
            GLES2.glDeleteShader(vertex_shader);
            GLES2.glDeleteShader(fragment_shader);
            return 0;
        }

        GLES2.glDeleteShader(vertex_shader);
        GLES2.glDeleteShader(fragment_shader);

        return program;
    }

    private void cleanup () {
        if (egl_context != EGL.EGL_NO_CONTEXT)
            EGL.eglDestroyContext(egl_display, egl_context);
        if (egl_surface != EGL.EGL_NO_SURFACE)
            EGL.eglDestroySurface(egl_display, egl_surface);
        if (egl_window != IntPtr.Zero)
            EGL.wl_egl_window_destroy(egl_window);
        if (egl_display != EGL.EGL_NO_DISPLAY)
            EGL.eglTerminate(egl_display);
        if (layer_surface != null)
            layer_surface.destroy();
        if (surface != null)
            surface.destroy();
    }

    public static int main (string[] args) {
        var panel = new LayerShellPanel();
        panel.setup_layer_surface();
        panel.setup_egl();
        panel.render_loop();
        panel.cleanup();
        return 0;
    }
}  */