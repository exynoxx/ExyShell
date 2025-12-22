using DrawKit;
using GLES2;

namespace Utils {
    
    public class Image {
        public static GLuint Upload_texture(string file_path, int size){
            GLuint tex;
            if(file_path.contains(".svg")){
                var image = DrawKit.image_from_svg(file_path,size,size);
                tex = DrawKit.texture_upload(*image);
            } else{
                var image = DrawKit.image_load(file_path);
                tex = DrawKit.texture_upload(image);
            }
    
            return tex;
        }
    }
}

