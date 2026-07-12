// v12 - 加诊断日志
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <fcntl.h>
#import "substrate.h"

static void wlog(NSString *m) {
    NSString *p = @"/var/jb/var/mobile/Documents/.qnlog.txt";
    NSString *l = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], m];
    NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!h) { [l writeToFile:p atomically:NO encoding:NSUTF8StringEncoding error:nil]; }
    else { [h seekToEndOfFile]; [h writeData:[l dataUsingEncoding:NSUTF8StringEncoding]]; [h closeFile]; }
}

static BOOL hookNo(id s, SEL c, ...) { return NO; }

static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id s, SEL c, NSString *p) {
    if (p && ([p hasPrefix:@"/var/jb"] || [p containsString:@"Cydia.app"])) return NO;
    return orig_fep(s, c, p);
}
static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id s, SEL c, NSURL *u) {
    NSString *l = u.absoluteString.lowercaseString;
    if ([l hasPrefix:@"sileo:"] || [l hasPrefix:@"cydia:"]) return NO;
    return orig_co(s, c, u);
}
static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id s, SEL c) {
    NSMutableDictionary *m = [orig_pe(s, c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"]; [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}
static int (*orig_sbn)(const char *, void *, size_t *, void *, size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (n && strcmp(n, "kern.bootargs") == 0) { if (o && ol) memset(o, 0, *ol); errno = ENOENT; return -1; }
    return orig_sbn(n, o, ol, nw, nl);
}
static pid_t (*orig_f)(void);
static pid_t hook_f(void) { errno = EPERM; return -1; }

__attribute__((constructor))
static void init(void) {
    wlog(@"=== CONSTRUCTOR STARTED ===");
    Class c = NSClassFromString(@"UIDevice");
    wlog(c ? @"UIDevice found" : @"UIDevice NOT FOUND");
    if (c) {
        SEL sl[] = { @selector(isJailbroken),@selector(isJailBreak),@selector(isDeviceJailbroken),@selector(isJailBroken) };
        for (int i = 0; i < sizeof(sl)/sizeof(SEL); i++) { Method m = class_getInstanceMethod(c, sl[i]); if (m) class_replaceMethod(c, sl[i], (IMP)hookNo, method_getTypeEncoding(m)); }
    }
    MSHookMessageEx(NSClassFromString(@"NSFileManager"), @selector(fileExistsAtPath:), (IMP)hook_fep, (IMP*)&orig_fep);
    MSHookMessageEx(NSClassFromString(@"UIApplication"), @selector(canOpenURL:), (IMP)hook_co, (IMP*)&orig_co);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"), @selector(environment), (IMP)hook_pe, (IMP*)&orig_pe);
    MSHookFunction((void *)sysctlbyname, (void *)hook_sbn, (void **)&orig_sbn);
    MSHookFunction((void *)fork, (void *)hook_f, (void **)&orig_f);
    wlog(@"=== ALL HOOKS DONE ===");
}
