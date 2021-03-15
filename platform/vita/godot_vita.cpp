#include <psp2/kernel/threadmgr.h>
#include <psp2/kernel/processmgr.h>
#include <psp2/message_dialog.h>

#include <sys/syslimits.h>
#include <stdlib.h>
#include <unistd.h>

#include "main/main.h"
#include "os_vita.h"

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

    void __sinit(struct _reent *);
}

__attribute__((constructor(101)))
void pthread_setup(void) 
{
    pthread_init();
    __sinit(_REENT);
}

int main(int argc, char *argv[])
{
    OS_Vita os;

	if (Main::start())
		os.run(); // it is actually the OS that decides how to run
	Main::cleanup();

    sceMsgDialogTerm();

	sceKernelExitProcess(os.get_exit_code());
}