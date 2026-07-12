// QNByPass - 去哪儿越狱屏蔽 (完整版)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import "substrate.h"

static BOOL hookNo(id _s, SEL _c, ...) { return NO; }

static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id _s, SEL _c, NSString *p) {
    if (p && ([p containsString:@"/var/jb"] || [p containsString:@"Cydia.app"] ||
              [p containsString:@"Sileo.app"] || [p containsString:@"Dopamine.app"]))
        return NO;
    return orig_fep(_s, _c, p);
}

static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id _s, SEL _c, NSURL *u) {
    NSString *s = u.absoluteString.lowercaseString;
    if ([s hasPrefix:@"sileo:"] || [s hasPrefix:@"cydia:"] || [s hasPrefix:@"dopamine:"])
        return NO;
    return orig_co(_s, _c, u);
}

static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id _s, SEL _c) {
    NSMutableDictionary *m = [orig_pe(_s, _c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}

static int (*orig_sbn)(const char *, void *, size_t *, void *, size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (n && strcmp(n, "kern.bootargs") == 0) {
        if (o && ol) memset(o, 0, *ol);
        errno = ENOENT; return -1;
    }
    return orig_sbn(n, o, ol, nw, nl);
}

static pid_t (*orig_f)(void);
static pid_t hook_f(void) { errno = EPERM; return -1; }

static int (*orig_sy)(const char *);
static int hook_sy(const char *c) { errno = EPERM; return -1; }

__attribute__((constructor))
static void qnbypass_init(void) {
    NSLog(@"[QNByPass] Loading...");
    
    // UIDevice
    Class c = NSClassFromString(@"UIDevice");
    if (c) {
        SEL sl[] = {
            @selector(isJailbroken),@selector(isJailBreak),@selector(isJailBroken),
            @selector(isDeviceJailbroken),@selector(checkJailbroken),@selector(isJailBrokenDevice),
            @selector(isCydiaJailBreak),@selector(isPathJailBreak),@selector(isJailBreak_appList),
            @selector(isJailBreak_cydia),@selector(isJailBreak_file),@selector(isJailBreak_env),
            @selector(isJailBreakByEnv),@selector(isJailBreakByStat),@selector(isJailbreak),
            @selector(isRootedOrJailbroken),@selector(o_pay_sdk_isJail)
        };
        for (int i = 0; i < sizeof(sl)/sizeof(SEL); i++) {
            Method m = class_getInstanceMethod(c, sl[i]);
            if (m) class_replaceMethod(c, sl[i], (IMP)hookNo, method_getTypeEncoding(m));
        }
    }
    
    // NSFileManager
    MSHookMessageEx(NSClassFromString(@"NSFileManager"), @selector(fileExistsAtPath:),
                    (IMP)hook_fep, (IMP*)&orig_fep);
    
    // UIApplication
    MSHookMessageEx(NSClassFromString(@"UIApplication"), @selector(canOpenURL:),
                    (IMP)hook_co, (IMP*)&orig_co);
    
    // NSProcessInfo
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"), @selector(environment),
                    (IMP)hook_pe, (IMP*)&orig_pe);
    
    // C functions
    MSHookFunction((void *)sysctlbyname, (void *)hook_sbn, (void **)&orig_sbn);
    MSHookFunction((void *)fork, (void *)hook_f, (void **)&orig_f);
    
    NSLog(@"[QNByPass] Loaded OK!");
}
