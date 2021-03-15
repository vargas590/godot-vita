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
}

int main(int argc, char *argv[])
{
    printf("Test godot!!!!");
    return 0;
}