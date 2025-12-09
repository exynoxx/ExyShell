R"(#version 100
    precision mediump float;
    varying vec2 vTexCoord;
    uniform sampler2D texture0;
    uniform vec4 color;
    uniform int mode; //0 = texture, 1 = text

    void main() {

        if(mode == 0){
            gl_FragColor = texture2D(texture0, vTexCoord) * color;
        } else if (mode == 1) {
            float a = texture2D(texture0, vTexCoord).r; // luminance -> sample red\n    
            // premultiply color by alpha
            gl_FragColor = vec4(color.rgb, color.a * a);
        }
    }
)"