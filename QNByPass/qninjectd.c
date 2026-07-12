// qninjectd.c - 守护进程 (launchd 自动后台化)
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <spawn.h>

extern char **environ;

#define TARGET "QunariPhone_Cook_CM"

static pid_t findPid(void) {
    FILE *f = popen("ps -eo pid,comm 2>/dev/null", "r");
    if (!f) return 0;
    char line[256]; pid_t pid = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, TARGET)) { sscanf(line, "%d", &pid); break; }
    }
    pclose(f);
    return pid;
}

int main(void) {
    pid_t lastPid = 0;
    while (1) {
        pid_t p = findPid();
        if (p > 0 && p != lastPid) {
            sleep(2);
            // RootHide bypass: 用 cp 复制 dylib 到 /tmp/
            pid_t cc; const char *cpa[] = {"/var/jb/bin/cp", "/var/jb/Library/MobileSubstrate/DynamicLibraries/QNByPass.dylib", "/tmp/QNByPass.dylib", NULL};
            posix_spawn(&cc, "/var/jb/bin/cp", NULL, NULL, (char*const*)cpa, environ);
            waitpid(cc, NULL, 0);
            char ps[16]; snprintf(ps, sizeof(ps), "%d", p);
            const char *a[] = {"/var/jb/usr/bin/opainject", ps, "/tmp/QNByPass.dylib", NULL};
            pid_t c;
            posix_spawn(&c, "/var/jb/usr/bin/opainject", NULL, NULL, (char*const*)a, environ);
            lastPid = p;
        }
        if (p == 0) lastPid = 0;
        sleep(3);
    }
}
