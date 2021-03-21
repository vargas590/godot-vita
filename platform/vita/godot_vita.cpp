#include <psp2/kernel/threadmgr.h>
#include <psp2/kernel/processmgr.h>
#include <psp2/message_dialog.h>
#include <psp2/kernel/clib.h>

#include <sys/syslimits.h>
#include <stdlib.h>
#include <unistd.h>

#include "main/main.h"
#include "os_vita.h"

#include <pib.h>
#include <EGL/egl.h>

#define MEMORY_SCELIBC_MB 50
#define MEMORY_NEWLIB_MB 30

extern "C"
{
    unsigned int sleep(unsigned int seconds)
    {
        sceKernelDelayThread(seconds*1000*1000);
        return 0;
    }

    int usleep(useconds_t usec)
    {
        sceKernelDelayThread(usec);
        return 0;
    }
    int sceLibcHeapSize = MEMORY_SCELIBC_MB * 1024 * 1024;
    int _newlib_heap_size_user = MEMORY_NEWLIB_MB * 1024 * 1024;
    unsigned int sceUserMainThreadStackSize = 7 * 1024 * 1024;
}


int main(int argc, char *argv[]) {
    PibError pibErr = pibInit((PibOptions)(PIB_SHACCCG, PIB_ENABLE_MSAA));
    sceClibPrintf("pibInit result: %d\n", pibErr);
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
    EGLDisplay display = eglGetDisplay(0);
    if (display == NULL) {
        sceClibPrintf("eglGetDisplay returned null");
    } else {
        eglInitialize(display, &majorVersion, &minorVersion);  //
    }
    sceClibPrintf("postEGLDisplay\n");
    sceKernelDelayThread(5*1000*1000);
    sceKernelExitProcess(0);
    return 0;
	OS_Vita os;
    sceClibPrintf("Showing the path now UwU: %d %s\n", argc, argv[0]);
	char* args[] = {"--path", "app0:/game_data"};

	Error err = Main::setup("", sizeof(args)/sizeof(args[0]), args);
	if (err != OK) {
//		free(cwd);
		return 255;
	}

	if (Main::start())
		os.run(); // it is actually the OS that decides how to run
	Main::cleanup();
//	chdir(cwd);
//	free(cwd);
	return 0;
}
