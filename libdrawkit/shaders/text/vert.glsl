R"(
    attribute vec2 a_pos;
    attribute vec2 a_uv;
    uniform mat4 u_proj;
    varying vec2 v_uv;
    void main() {
        gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);
        v_uv = a_uv;
    };
)"