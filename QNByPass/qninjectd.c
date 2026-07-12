// qninjectd.c - 守护进程 + 日志
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <spawn.h>
#include <time.h>

extern char **environ;

static void logMsg(const char *msg) {
    FILE *f = fopen("/var/jb/var/mobile/Documents/.qninjectd.log", "a");
    if (f) { time_t t=time(0); fprintf(f,"%.24s %s\n", ctime(&t), msg); fclose(f); }
}

static pid_t findPid(void) {
    FILE *f = popen("ps -eo pid,comm 2>/dev/null", "r");
    if (!f) { logMsg("popen failed"); return 0; }
    char line[256]; pid_t pid = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "QunariPhone_Cook_CM")) { sscanf(line, "%d", &pid); break; }
    }
    pclose(f);
    return pid;
}

int main(void) {
    logMsg("Daemon started");
    pid_t lastPid = 0;
    while (1) {
        pid_t p = findPid();
        if (p > 0 && p != lastPid) {
            char buf[128];
            snprintf(buf, sizeof(buf), "Found Qunar PID=%d, injecting...", p);
            logMsg(buf);
            sleep(2);
            // Copy dylib
            pid_t cp; const char *cpa[] = {"/var/jb/bin/cp", "/var/jb/Library/MobileSubstrate/DynamicLibraries/QNByPass.dylib", "/tmp/QNByPass.dylib", NULL};
            int r1 = posix_spawn(&cp, "/var/jb/bin/cp", NULL, NULL, (char*const*)cpa, environ);
            snprintf(buf, sizeof(buf), "cp result=%d", r1); logMsg(buf);
            // Inject
            char ps[16]; snprintf(ps, sizeof(ps), "%d", p);
            const char *a[] = {"/var/jb/usr/bin/opainject", ps, "/tmp/QNByPass.dylib", NULL};
            pid_t c;
            int r2 = posix_spawn(&c, "/var/jb/usr/bin/opainject", NULL, NULL, (char*const*)a, environ);
            snprintf(buf, sizeof(buf), "opainject result=%d child=%d", r2, c); logMsg(buf);
            lastPid = p;
        }
        if (p == 0) lastPid = 0;
        sleep(3);
    }
}

