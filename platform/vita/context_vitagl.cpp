#include "context_vitagl.h"
#include <pib.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <psp2/message_dialog.h>
#include "core/error_list.h"

Error Context_VitaGL::initialize() {
    PibOptions options = (PibOptions)(PIB_SHACCCG | PIB_NOSTDLIB | PIB_ENABLE_MSAA);
    pibInit(options);

    display = eglGetDisplay(0);

    EGLint majorVersion;
    EGLint minorVersion;
    EGLint numConfigs = 0;
    EGLConfig config;
    EGLint configAttribs[] = {
        //EGL_CONFIG_ID, 2,                         // You can always provide a configuration id. The one displayed here is Configuration 2
        EGL_RED_SIZE, 8,                            // These four are always 8
        EGL_GREEN_SIZE, 8,                          //
        EGL_BLUE_SIZE, 8,                           //
        EGL_ALPHA_SIZE, 8,                          //
        EGL_DEPTH_SIZE, 32,                         // Depth is either 32 or 0 (16 does work as well, but has the same effect as using 32)
        EGL_STENCIL_SIZE, 8,                        // Stencil Size is either 8 or 0
        EGL_SURFACE_TYPE, 5,                        // This is ALWAYS 5
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,    // Always EGL_OPENGL_ES2_BIT or 0x4
        EGL_NONE};
    const EGLint contextAttribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE };

    eglInitialize(display, &majorVersion, &minorVersion);  // You can use these boolean returns for error handling. This is not shown here

    eglBindAPI(EGL_OPENGL_ES_API);

    eglChooseConfig(display, configAttribs, &config, 1, &numConfigs);

    surface = eglCreateWindowSurface(display, config, VITA_WINDOW_960X544, NULL);  // You can choose your display resoltion, up to 1080p on the PSTV (Vita requires SharpScale)

    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);

    eglMakeCurrent(display, surface, surface, context);
    eglQuerySurface(display, surface, EGL_WIDTH, &surface_width);
    eglQuerySurface(display, surface, EGL_HEIGHT, &surface_height);
    return OK;
}

void Context_VitaGL::swap_buffers() {
    eglSwapBuffers(display, surface);
}