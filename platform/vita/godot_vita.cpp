#include <psp2/kernel/threadmgr.h>
#include <psp2/kernel/processmgr.h>
#include <psp2/message_dialog.h>
#include <psp2/kernel/clib.h>
#include <psp2/kernel/iofilemgr.h>

#include <sys/syslimits.h>
#include <stdlib.h>
#include <unistd.h>

#include "main/main.h"
#include "os_vita.h"

#include <pib.h>
#include <EGL/egl.h>

#include <psp2/kernel/modulemgr.h>

#define MEMORY_SCELIBC_MB 15
#define MEMORY_NEWLIB_MB 280
# define SCE_NULL NULL
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
    unsigned int sceUserMainThreadStackSize = 4 * 1024 * 1024;
}

static char searchDir[200] = "ur0:data/external/"; // Max Path Length
static char modulePath[200];

static char *getModulePath(const char *moduleName)
{
    memset(modulePath, '\0', sizeof(modulePath));
    strncpy(modulePath, searchDir, strlen(searchDir));
    strncat(modulePath, moduleName, strlen(moduleName));
    return modulePath;
}

int main(int argc, char *argv[]) {
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
