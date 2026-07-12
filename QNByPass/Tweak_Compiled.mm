/*
 * Tweak_Compiled.mm
 * 纯 ObjC++ 版本 (不需要 Logos 预处理)
 * 直接使用 Cydia Substrate C API
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <objc/runtime.h>
#import "substrate.h"

// ============================================================
// MARK: - 辅助
// ============================================================

static NSSet *jailbreakPaths(void) {
    static NSSet *paths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        paths = [[NSSet alloc] initWithArray:@[
            @"/var/jb", @"/var/jb/Applications", @"/var/jb/bin/bash",
            @"/var/jb/etc/apt", @"/var/jb/Library/MobileSubstrate",
            @"/Applications/Cydia.app", @"/Applications/Sileo.app",
            @"/Applications/Dopamine.app", @"/Applications/Zebra.app",
            @"/bin/bash", @"/etc/apt", @"/usr/sbin/sshd",
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/.installed_unc0ver", @"/.bootstrapped_electra",
        ]];
    });
    return paths;
}

static NSSet *jailbreakURLSchemes(void) {
    static NSSet *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[NSSet alloc] initWithArray:@[
            @"sileo://", @"cydia://", @"dopamine://", @"zbra://",
            @"zebra://", @"undecimus://", @"filza://", @"activator://"
        ]];
    });
    return s;
}

// ============================================================
// MARK: - 1. UIDevice Hook
// ============================================================

static BOOL (*orig_UIDevice_isJailbroken)(id, SEL);
static BOOL hooked_UIDevice_isJailbroken(id self, SEL _cmd) { return NO; }

static BOOL (*orig_UIDevice_isJailBreak)(id, SEL);
static BOOL hooked_UIDevice_isJailBreak(id self, SEL _cmd) { return NO; }

static BOOL (*orig_UIDevice_isJailBroken)(id, SEL);
static BOOL hooked_UIDevice_isJailBroken(id self, SEL _cmd) { return NO; }

static void hookUIDevice(void) {
    Class cls = NSClassFromString(@"UIDevice");
    if (!cls) return;
    
    MSHookMessageEx(cls, @selector(isJailbroken),
        (IMP)hooked_UIDevice_isJailbroken, (IMP*)&orig_UIDevice_isJailbroken);
    MSHookMessageEx(cls, @selector(isJailBreak),
        (IMP)hooked_UIDevice_isJailBreak, (IMP*)&orig_UIDevice_isJailBreak);
    MSHookMessageEx(cls, @selector(isJailBroken),
        (IMP)hooked_UIDevice_isJailBroken, (IMP*)&orig_UIDevice_isJailBroken);
    
    // Hook all "isJailBreak*" methods on UIDevice
    unsigned int count;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        if ([name containsString:@"isJail"] || [name containsString:@"Jailbreak"] ||
            [name containsString:@"jailbreak"] || [name containsString:@"jailBroken"] ||
            [name containsString:@"checkJail"] || [name containsString:@"AmIJailbroken"] ||
            [name containsString:@"isRooted"] || [name containsString:@"isCydia"] ||
            [name containsString:@"isDFP"] || [name containsString:@"isDebuggerCheck"] ||
            [name containsString:@"o_pay_check"] || [name containsString:@"o_pay_sdk_isJail"]) {
            
            IMP imp = imp_implementationWithBlock(^(id _self) { return (BOOL)NO; });
            class_replaceMethod(cls, sel, imp, method_getTypeEncoding(methods[i]));
        }
    }
    free(methods);
    
    NSLog(@"[QNByPass] UIDevice hooked");
}

// ============================================================
// MARK: - 2. NSFileManager Hook
// ============================================================

static BOOL (*orig_fileExistsAtPath_)(id, SEL, NSString *);
static BOOL hooked_fileExistsAtPath_(id self, SEL _cmd, NSString *path) {
    if (path && [jailbreakPaths() containsObject:path]) return NO;
    for (NSString *jp in jailbreakPaths()) {
        if ([path hasPrefix:jp]) return NO;
    }
    return orig_fileExistsAtPath_(self, _cmd, path);
}

static void hookNSFileManager(void) {
    Class cls = NSClassFromString(@"NSFileManager");
    MSHookMessageEx(cls, @selector(fileExistsAtPath:),
        (IMP)hooked_fileExistsAtPath_, (IMP*)&orig_fileExistsAtPath_);
    NSLog(@"[QNByPass] NSFileManager hooked");
}

// ============================================================
// MARK: - 3. UIApplication canOpenURL Hook
// ============================================================

static BOOL (*orig_canOpenURL)(id, SEL, NSURL *);
static BOOL hooked_canOpenURL(id self, SEL _cmd, NSURL *url) {
    NSString *str = [url absoluteString];
    for (NSString *s in jailbreakURLSchemes()) {
        if ([str.lowercaseString hasPrefix:s.lowercaseString]) return NO;
    }
    return orig_canOpenURL(self, _cmd, url);
}

static void hookUIApplication(void) {
    Class cls = NSClassFromString(@"UIApplication");
    MSHookMessageEx(cls, @selector(canOpenURL:),
        (IMP)hooked_canOpenURL, (IMP*)&orig_canOpenURL);
    NSLog(@"[QNByPass] UIApplication hooked");
}

// ============================================================
// MARK: - 4. NSProcessInfo Hook
// ============================================================

static NSDictionary *(*orig_environment)(id, SEL);
static NSDictionary *hooked_environment(id self, SEL _cmd) {
    NSMutableDictionary *env = [orig_environment(self, _cmd) mutableCopy];
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return env;
}

static void hookNSProcessInfo(void) {
    Class cls = NSClassFromString(@"NSProcessInfo");
    MSHookMessageEx(cls, @selector(environment),
        (IMP)hooked_environment, (IMP*)&orig_environment);
    NSLog(@"[QNByPass] NSProcessInfo hooked");
}

// ============================================================
// MARK: - 5. sysctl Hook
// ============================================================

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name && (strcmp(name, "kern.bootargs") == 0 ||
        strstr(name, "security.mac.") != NULL)) {
        if (oldp && oldlenp) memset(oldp, 0, *oldlenp);
        errno = ENOENT;
        return -1;
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// ============================================================
// MARK: - 6. stat/access Hook
// ============================================================

static int (*orig_stat)(const char *, struct stat *);
static int (*orig_lstat)(const char *, struct stat *);
static int (*orig_access)(const char *, int);

static BOOL isJPath(const char *p) {
    if (!p) return NO;
    NSString *s = @(p);
    if ([s hasPrefix:@"/var/jb"]) return YES;
    if ([s containsString:@"Cydia.app"]) return YES;
    if ([s containsString:@"Sileo.app"]) return YES;
    if ([s containsString:@"Dopamine.app"]) return YES;
    if ([s containsString:@"frida"]) return YES;
    return NO;
}

static int hooked_stat(const char *p, struct stat *b) {
    if (isJPath(p)) { errno = ENOENT; return -1; }
    return orig_stat(p, b);
}
static int hooked_lstat(const char *p, struct stat *b) {
    if (isJPath(p)) { errno = ENOENT; return -1; }
    return orig_lstat(p, b);
}
static int hooked_access(const char *p, int m) {
    if (isJPath(p)) { errno = EACCES; return -1; }
    return orig_access(p, m);
}

// ============================================================
// MARK: - 7. fork/system Hook
// ============================================================

static pid_t (*orig_fork)(void);
static pid_t hooked_fork(void) { errno = EPERM; return -1; }

static int (*orig_system)(const char *);
static int hooked_system(const char *c) { errno = EPERM; return -1; }

// ============================================================
// MARK: - 8. 第三方SDK Hook
// ============================================================

static void hookSDKClass(NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls) return;
    
    unsigned int count;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        if ([name containsString:@"isJail"] || [name containsString:@"jail"] ||
            [name containsString:@"Jail"]) {
            IMP imp = imp_implementationWithBlock(^(id _self) { return (BOOL)NO; });
            class_replaceMethod(cls, sel, imp, method_getTypeEncoding(methods[i]));
        }
    }
    // Also replace class methods
    Method *cmethods = class_copyMethodList(object_getClass(cls), &count);
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(cmethods[i]);
        NSString *name = NSStringFromSelector(sel);
        if ([name containsString:@"isJail"] || [name containsString:@"jail"]) {
            IMP imp = imp_implementationWithBlock(^(id _self) { return (BOOL)NO; });
            class_replaceMethod(object_getClass(cls), sel, imp, method_getTypeEncoding(cmethods[i]));
        }
    }
    free(methods);
    free(cmethods);
    
    NSLog(@"[QNByPass] %@ hooked", className);
}

// ============================================================
// MARK: - %ctor
// ============================================================

__attribute__((constructor))
static void QNByPassInit(void) {
    @autoreleasepool {
        NSLog(@"[QNByPass] === Qunar Jailbreak Bypass Loading ===");
        
        // ObjC hooks
        hookUIDevice();
        hookNSFileManager();
        hookUIApplication();
        hookNSProcessInfo();
        
        // SDK hooks
        hookSDKClass(@"DTTJailbreakDetection");
        hookSDKClass(@"OneSignalJailbreakDetection");
        hookSDKClass(@"JailbreakDetection");
        hookSDKClass(@"JailbreakDetectionVC");
        hookSDKClass(@"RVPBridgeExtension4Jailbroken");
        
        // C function hooks
        MSHookFunction((void *)sysctl, (void *)hooked_sysctl, (void **)&orig_sysctl);
        MSHookFunction((void *)sysctlbyname, (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname);
        MSHookFunction((void *)stat, (void *)hooked_stat, (void **)&orig_stat);
        MSHookFunction((void *)lstat, (void *)hooked_lstat, (void **)&orig_lstat);
        MSHookFunction((void *)access, (void *)hooked_access, (void **)&orig_access);
        MSHookFunction((void *)fork, (void *)hooked_fork, (void **)&orig_fork);
        MSHookFunction((void *)system, (void *)hooked_system, (void **)&orig_system);
        
        NSLog(@"[QNByPass] === Loaded! %lu hooks ===", (unsigned long)7);
    }
}
