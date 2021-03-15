#include <psp2/kernel/threadmgr.h>
#include <psp2/kernel/processmgr.h>
#include <psp2/message_dialog.h>

#include <sys/syslimits.h>
#include <stdlib.h>
#include <unistd.h>

#include "main/main.h"
#include "os_vita.h"

#include <locale.h>

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
}

int main(int argc, char *argv[])
{
    printf("Test godot!!!!");
    return 0;
    OS_Vita os;

    setlocale(LC_CTYPE, "");

    char* args[] = {"-path", "ux0:/data/godot"};

    Error err = Main::setup(argv[0], argc - 1, &argv[1]);

    if (err != OK) {
        return 255;
    }

	if (Main::start())
		os.run(); // it is actually the OS that decides how to run
	Main::cleanup();

    sceMsgDialogTerm();

	sceKernelExitProcess(os.get_exit_code());
    return 0;
}