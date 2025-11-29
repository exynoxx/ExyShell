R"(
    precision mediump float;
    varying vec2 v_uv;
    uniform sampler2D u_tex;
    uniform vec4 u_color;
    void main() {
        float a = texture2D(u_tex, v_uv).r; // luminance -> sample red\n    
        // premultiply color by alpha
        gl_FragColor = vec4(u_color.rgb, u_color.a * a);
    };
)"