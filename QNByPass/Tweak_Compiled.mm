// Tweak_Compiled.mm - 极简版（避免高级 ObjC runtime 问题）
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "substrate.h"

// ============ UIDevice Hook ============
static BOOL hooked_device_check(id self, SEL _cmd, ...) { return NO; }

// ============ NSFileManager Hook ============
static BOOL (*orig_fileExists)(id, SEL, NSString *);
static BOOL hooked_fileExists(id self, SEL _cmd, NSString *path) {
    if (!path) return orig_fileExists(self, _cmd, path);
    if ([path containsString:@"/var/jb"] || [path containsString:@"Cydia.app"] ||
        [path containsString:@"Sileo.app"] || [path containsString:@"Dopamine.app"] ||
        [path containsString:@"frida"]) return NO;
    return orig_fileExists(self, _cmd, path);
}

// ============ UIApplication Hook ============
static BOOL (*orig_canOpen)(id, SEL, NSURL *);
static BOOL hooked_canOpen(id self, SEL _cmd, NSURL *url) {
    NSString *s = [url absoluteString].lowercaseString;
    if ([s hasPrefix:@"sileo:"] || [s hasPrefix:@"cydia:"] || [s hasPrefix:@"dopamine:"] ||
        [s hasPrefix:@"zbra:"] || [s hasPrefix:@"undecimus:"] || [s hasPrefix:@"filza:"] ||
        [s hasPrefix:@"activator:"] || [s hasPrefix:@"jbroot:"]) return NO;
    return orig_canOpen(self, _cmd, url);
}

// ============ NSProcessInfo Hook ============
static NSDictionary *(*orig_env)(id, SEL);
static NSDictionary *hooked_env(id self, SEL _cmd) {
    NSDictionary *d = orig_env(self, _cmd);
    NSMutableDictionary *m = [d mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}

// ============ C function hooks ============
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);
static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name && (strcmp(name, "kern.bootargs") == 0 || strstr(name, "security.mac."))) {
        if (oldp && oldlenp) memset(oldp, 0, *oldlenp);
        errno = ENOENT; return -1;
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

static pid_t (*orig_fork)(void);
static pid_t hooked_fork(void) { errno = EPERM; return -1; }

static int (*orig_system)(const char *);
static int hooked_system(const char *c) { errno = EPERM; return -1; }

static int (*orig_stat)(const char *, struct stat *);
static int hooked_stat(const char *p, struct stat *b) {
    if (p && (strstr(p, "/var/jb") || strstr(p, "Cydia") || strstr(p, "Sileo") || strstr(p, "frida"))) {
        errno = ENOENT; return -1;
    }
    return orig_stat(p, b);
}

// ============ Constructor ============
__attribute__((constructor))
static void init(void) {
    @autoreleasepool {
        // UIDevice hook
        Class c = NSClassFromString(@"UIDevice");
        if (c) {
            SEL methods[] = {
                @selector(isJailbroken), @selector(isJailBreak), @selector(isJailBroken),
                @selector(AmIJailbroken_), @selector(isDeviceJailbroken), @selector(checkJailbroken),
                @selector(isJailBrokenDevice), @selector(isJailbrokenDetected),
                @selector(isCydiaJailBreak), @selector(isPathJailBreak),
                @selector(isDebuggerCheckDetectedByVOS), @selector(isDFPHookedDetecedByVOS),
                @selector(o_pay_check_touchid_isjailbreak), @selector(o_pay_sdk_isJail),
                @selector(boolIsjailbreak), @selector(computeIsJailbroken),
                @selector(isJailBreak_appList), @selector(isJailBreak_cydia),
                @selector(isJailBreak_file), @selector(isJailBreak_env),
                @selector(isJailBreakByEnv), @selector(isJailBreakByStat),
                @selector(isRootedOrJailbroken), @selector(isDeviceNonCompliant),
                @selector(isJailbreak), @selector(isJailBreakon), @selector(is_jail),
            };
            for (int i = 0; i < sizeof(methods)/sizeof(SEL); i++) {
                Method m = class_getInstanceMethod(c, methods[i]);
                if (m) class_replaceMethod(c, methods[i], (IMP)hooked_device_check, method_getTypeEncoding(m));
            }
            // Class methods
            unsigned int ccount = 0;
            Method *clm = class_copyMethodList(object_getClass(c), &ccount);
            if (clm) {
                for (unsigned int i = 0; i < ccount; i++) {
                    SEL s = method_getName(clm[i]);
                    NSString *ns = NSStringFromSelector(s);
                    if ([ns containsString:@"Jail"] || [ns containsString:@"jail"])
                        class_replaceMethod(object_getClass(c), s, (IMP)hooked_device_check, method_getTypeEncoding(clm[i]));
                }
                free(clm);
            }
        }
        
        // NSFileManager
        c = NSClassFromString(@"NSFileManager");
        MSHookMessageEx(c, @selector(fileExistsAtPath:), (IMP)hooked_fileExists, (IMP*)&orig_fileExists);
        
        // UIApplication
        c = NSClassFromString(@"UIApplication");
        MSHookMessageEx(c, @selector(canOpenURL:), (IMP)hooked_canOpen, (IMP*)&orig_canOpen);
        
        // NSProcessInfo
        c = NSClassFromString(@"NSProcessInfo");
        MSHookMessageEx(c, @selector(environment), (IMP)hooked_env, (IMP*)&orig_env);
        
        // C functions
        MSHookFunction((void *)sysctlbyname, (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname);
        MSHookFunction((void *)fork, (void *)hooked_fork, (void **)&orig_fork);
        MSHookFunction((void *)system, (void *)hooked_system, (void **)&orig_system);
        MSHookFunction((void *)stat, (void *)hooked_stat, (void **)&orig_stat);
        
        NSLog(@"[QNByPass] Loaded!");
    }
}
