// qninjectd.c - 守护进程：监控去哪儿启动并注入 dylib
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <dispatch/dispatch.h>

#define TARGET_NAME "QunariPhone_Cook_CM"
#define DYLIB_PATH "/var/jb/Library/MobileSubstrate/DynamicLibraries/QNByPass.dylib"
#define INJECT_TOOL "/var/jb/usr/bin/opainject"

static pid_t findQunar(void) {
    FILE *f = popen("ps -eo pid,comm | grep " TARGET_NAME " | grep -v grep | awk '{print $1}'", "r");
    if (!f) return 0;
    char buf[32];
    if (fgets(buf, sizeof(buf), f)) {
        pclose(f);
        return (pid_t)atoi(buf);
    }
    pclose(f);
    return 0;
}

static void inject(pid_t pid) {
    pid_t child;
    const char *argv[] = {INJECT_TOOL, NULL, NULL, NULL};
    char pidStr[16];
    snprintf(pidStr, sizeof(pidStr), "%d", pid);
    argv[1] = pidStr;
    argv[2] = DYLIB_PATH;
    
    // 后台执行，不等待
    posix_spawn(&child, INJECT_TOOL, NULL, NULL, (char*const*)argv, NULL);
    printf("[qninjectd] Injected PID %d\n", pid);
}

int main(void) {
    // 守护进程化
    pid_t pid = fork();
    if (pid < 0) exit(1);
    if (pid > 0) exit(0);  // parent exits
    setsid();
    
    printf("[qninjectd] Started, watching for %s\n", TARGET_NAME);
    
    // 每 3 秒扫描一次
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    
    static pid_t lastPid = 0;
    dispatch_source_set_event_handler(timer, ^{
        pid_t current = findQunar();
        if (current > 0 && current != lastPid) {
            sleep(1); // 等 App 初始化完
            inject(current);
            lastPid = current;
        }
        if (current == 0) lastPid = 0;
    });
    
    dispatch_resume(timer);
    dispatch_main();
    return 0;
}
