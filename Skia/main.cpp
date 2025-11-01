#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <iostream>
#include "include/core/SkSurface.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkPaint.h"
#include "include/gpu/ganesh/gl/GrGLInterface.h"
#include "include/gpu/ganesh/GrRecordingContext.h"
#include "include/gpu/ganesh/GrDirectContext.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"

const int WIDTH = 800;
const int HEIGHT = 600;

int main() {
    // Initialize EGL
    EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) {
        std::cerr << "Failed to get EGL display\n";
        return 1;
    }

    EGLint major, minor;
    if (!eglInitialize(display, &major, &minor)) {
        std::cerr << "Failed to initialize EGL\n";
        return 1;
    }

    std::cout << "EGL version: " << major << "." << minor << "\n";

    // Choose config
    EGLint configAttribs[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE
    };

    EGLConfig config;
    EGLint numConfigs;
    if (!eglChooseConfig(display, configAttribs, &config, 1, &numConfigs)) {
        std::cerr << "Failed to choose EGL config\n";
        return 1;
    }

    // Create pbuffer surface
    EGLint surfaceAttribs[] = {
        EGL_WIDTH, WIDTH,
        EGL_HEIGHT, HEIGHT,
        EGL_NONE
    };

    EGLSurface surface = eglCreatePbufferSurface(display, config, surfaceAttribs);
    if (surface == EGL_NO_SURFACE) {
        std::cerr << "Failed to create EGL surface\n";
        return 1;
    }

    // Bind API and create context
    eglBindAPI(EGL_OPENGL_ES_API);

    EGLint contextAttribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };

    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);
    if (context == EGL_NO_CONTEXT) {
        std::cerr << "Failed to create EGL context\n";
        return 1;
    }

    if (!eglMakeCurrent(display, surface, surface, context)) {
        std::cerr << "Failed to make EGL context current\n";
        return 1;
    }


    




    // Initialize Skia
    auto interface = GrGLMakeNativeInterface();
    if (!interface) {
        std::cerr << "Failed to create GrGLInterface\n";
        return 1;
    }

    auto grContext = GrDirectContext::GrDirectContext(std::move(interface));
    if (!grContext) {
        std::cerr << "Failed to create GrDirectContext\n";
        return 1;
    }

    GrGLFramebufferInfo fbInfo;
    fbInfo.fFBOID = 0;
    fbInfo.fFormat = GL_RGBA8;

    GrBackendRenderTarget backendRT(1000,
                                    200,
                                    /*sampelCount=*/1,
                                    /*stencilBits=*/8,
                                    fbInfo);

    sk_sp<SkSurface> gpuSurface = SkSurface::MakeFromBackendRenderTarget(context.get(), backendRT,
                                                                        kBottomLeft_GrSurfaceOrigin,
                                                                        kRGBA_8888_SkColorType,
                                                                        /*colorSpace=*/nullptr,
                                                                        /*surfaceProps=*/nullptr);


    // Create surface with Ganesh (modern Skia API)
    SkImageInfo imageInfo = SkImageInfo::Make(WIDTH, HEIGHT, kRGBA_8888_SkColorType, kPremul_SkAlphaType);
    auto surface_sk = SkSurfaces::WrapBackendRenderTarget(
        grContext.get(),
        GrBackendRenderTarget(WIDTH, HEIGHT, 0, 0, GrGLFramebufferInfo{0, GL_RGBA4}),
        kBottomLeft_GrSurfaceOrigin,
        kRGBA_8888_SkColorType,
        nullptr,
        nullptr
    );

    if (!surface_sk) {
        std::cerr << "Failed to create Skia surface\n";
        return 1;
    }

    // Draw with Skia
    SkCanvas* canvas = surface_sk->getCanvas();

    SkPaint paint;
    paint.setColor(SK_ColorWHITE);
    canvas->drawPaint(paint);

    paint.setColor(SK_ColorBLUE);
    canvas->drawRect(SkRect::MakeXYWH(100, 100, 200, 200), paint);

    paint.setColor(SK_ColorRED);
    canvas->drawCircle(400, 300, 50, paint);

    paint.setColor(SK_ColorGREEN);
    paint.setStrokeWidth(3);
    paint.setStyle(SkPaint::kStroke_Style);
    canvas->drawRect(SkRect::MakeXYWH(550, 150, 150, 250), paint);

    surface_sk->flushAndSubmit();

    std::cout << "Rendered successfully to " << WIDTH << "x" << HEIGHT << " surface\n";

    // Cleanup
    surface_sk.reset();
    grContext.reset();
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, context);
    eglDestroySurface(display, surface);
    eglTerminate(display);

    return 0;
}