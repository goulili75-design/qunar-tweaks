// qninjectd.c - 守护进程 (纯C，无dispatch依赖)
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <string.h>

#define TARGET "QunariPhone_Cook_CM"
#define DYLIB "/var/jb/Library/MobileSubstrate/DynamicLibraries/QNByPass.dylib"
#define INJECTOR "/var/jb/usr/bin/opainject"

static pid_t findPid(void) {
    FILE *f = popen("ps -eo pid,comm", "r");
    if (!f) return 0;
    char line[256]; pid_t pid = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, TARGET)) {
            sscanf(line, "%d", &pid); break;
        }
    }
    pclose(f);
    return pid;
}

int main(void) {
    // daemonize
    if (fork() > 0) return 0;
    setsid();
    
    pid_t lastPid = 0;
    while (1) {
        pid_t p = findPid();
        if (p > 0 && p != lastPid) {
            sleep(2); // 等 App 初始化
            char pidStr[16]; snprintf(pidStr, sizeof(pidStr), "%d", p);
            pid_t child;
            const char *argv[] = {INJECTOR, pidStr, DYLIB, NULL};
            posix_spawn(&child, INJECTOR, NULL, NULL, (char*const*)argv, NULL);
            lastPid = p;
        }
        if (p == 0) lastPid = 0;
        sleep(3);
    }
}
