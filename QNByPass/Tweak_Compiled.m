// QNByPass - 去哪儿越狱屏蔽 (完整版 v5)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <dlfcn.h>
#import <unistd.h>
#import "substrate.h"

// ============ ObjC Hooks ============

static BOOL hookNo(id s, SEL c, ...) { return NO; }

static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id s, SEL c, NSString *p) {
    if (p) {
        if ([p hasPrefix:@"/var/jb"]) return NO;
        if ([p hasPrefix:@"/Library/MobileSubstrate"]) return NO;
        if ([p hasPrefix:@"/Library/dpkg"]) return NO;
        if ([p containsString:@"Cydia.app"]) return NO;
        if ([p containsString:@"Sileo.app"]) return NO;
        if ([p containsString:@"Dopamine.app"]) return NO;
        if ([p containsString:@"Zebra.app"]) return NO;
        if ([p containsString:@"frida"]) return NO;
        if ([p containsString:@"palera1n"]) return NO;
    }
    return orig_fep(s, c, p);
}

static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id s, SEL c, NSURL *u) {
    NSString *str = u.absoluteString.lowercaseString;
    if ([str hasPrefix:@"sileo:"] || [str hasPrefix:@"cydia:"] || 
        [str hasPrefix:@"dopamine:"] || [str hasPrefix:@"zbra:"] ||
        [str hasPrefix:@"undecimus:"] || [str hasPrefix:@"filza:"] ||
        [str hasPrefix:@"activator:"] || [str hasPrefix:@"jbroot:"] ||
        [str hasPrefix:@"ssh:"] || [str hasPrefix:@"xina:"]) return NO;
    return orig_co(s, c, u);
}

static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id s, SEL c) {
    NSMutableDictionary *m = [orig_pe(s, c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}

// ============ C Function Hooks ============

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int hook_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

static int (*orig_sbn)(const char *, void *, size_t *, void *, size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (n && (strcmp(n,"kern.bootargs")==0 || strstr(n,"security.mac."))) {
        if (o && ol) memset(o, 0, *ol);
        errno = ENOENT; return -1;
    }
    return orig_sbn(n, o, ol, nw, nl);
}

// stat / lstat / access — 最关键的越狱文件检测！
static int (*orig_stat)(const char *, struct stat *);
static int hook_stat(const char *p, struct stat *b) {
    if (p && (strstr(p,"/var/jb") || strstr(p,"Cydia") || strstr(p,"Sileo") ||
              strstr(p,"Dopamine") || strstr(p,"frida") || strstr(p,"palera1n") ||
              strstr(p,"/Library/MobileSubstrate") || strstr(p,"/Library/dpkg"))) {
        errno = ENOENT; return -1;
    }
    return orig_stat(p, b);
}

static int (*orig_lstat)(const char *, struct stat *);
static int hook_lstat(const char *p, struct stat *b) {
    if (p && (strstr(p,"/var/jb") || strstr(p,"Cydia") || strstr(p,"Sileo") ||
              strstr(p,"frida"))) {
        errno = ENOENT; return -1;
    }
    return orig_lstat(p, b);
}

static int (*orig_access)(const char *, int);
static int hook_access(const char *p, int m) {
    if (p && (strstr(p,"/var/jb") || strstr(p,"Cydia") || strstr(p,"Sileo"))) {
        errno = EACCES; return -1;
    }
    return orig_access(p, m);
}

// fork / system — 沙箱逃逸检测
static pid_t (*orig_fork)(void);
static pid_t hook_fork(void) { errno = EPERM; return -1; }

static int (*orig_system)(const char *);
static int hook_system(const char *c) { errno = EPERM; return -1; }

// dladdr — dylib 加载检测
static int (*orig_dladdr)(const void *, Dl_info *);
static int hook_dladdr(const void *addr, Dl_info *info) {
    int ret = orig_dladdr(addr, info);
    if (ret != 0 && info && info->dli_fname) {
        const char *f = info->dli_fname;
        if (strstr(f,"SubstrateLoader") || strstr(f,"TweakInject") ||
            strstr(f,"frida") || strstr(f,"CydiaSubstrate") ||
            strstr(f,"libhooker") || strstr(f,"Substitute")) {
            info->dli_fname = "/usr/lib/libSystem.B.dylib";
            info->dli_sname = NULL;
            info->dli_saddr = NULL;
        }
        // 不要拦截 ATHelper / qninjector / libsubstrate！
    }
    return ret;
}

// ============ Constructor ============
__attribute__((constructor))
static void qnbypass_init(void) {
    // UIDevice hooks
    Class c = NSClassFromString(@"UIDevice");
    if (c) {
        SEL sl[] = {
            @selector(isJailbroken),@selector(isJailBreak),@selector(isJailBroken),
            @selector(isDeviceJailbroken),@selector(checkJailbroken),@selector(isJailBrokenDevice),
            @selector(isCydiaJailBreak),@selector(isPathJailBreak),@selector(isJailBreak_appList),
            @selector(isJailBreak_cydia),@selector(isJailBreak_file),@selector(isJailBreak_env),
            @selector(isJailBreakByEnv),@selector(isJailBreakByStat),@selector(isJailbreak),
            @selector(isRootedOrJailbroken),@selector(o_pay_sdk_isJail),@selector(boolIsjailbreak),
            @selector(computeIsJailbroken),@selector(isJailbreakDetected),@selector(jailBrokenJudge)
        };
        for (int i=0;i<sizeof(sl)/sizeof(SEL);i++) {
            Method m = class_getInstanceMethod(c, sl[i]);
            if (m) class_replaceMethod(c, sl[i], (IMP)hookNo, method_getTypeEncoding(m));
        }
    }
    
    // ObjC hooks
    MSHookMessageEx(NSClassFromString(@"NSFileManager"),@selector(fileExistsAtPath:),(IMP)hook_fep,(IMP*)&orig_fep);
    MSHookMessageEx(NSClassFromString(@"UIApplication"),@selector(canOpenURL:),(IMP)hook_co,(IMP*)&orig_co);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"),@selector(environment),(IMP)hook_pe,(IMP*)&orig_pe);
    
    // C function hooks — 这是最关键的！
    MSHookFunction((void *)sysctl, (void *)hook_sysctl, (void **)&orig_sysctl);
    MSHookFunction((void *)sysctlbyname, (void *)hook_sbn, (void **)&orig_sbn);
    MSHookFunction((void *)stat, (void *)hook_stat, (void **)&orig_stat);
    MSHookFunction((void *)lstat, (void *)hook_lstat, (void **)&orig_lstat);
    MSHookFunction((void *)access, (void *)hook_access, (void **)&orig_access);
    MSHookFunction((void *)fork, (void *)hook_fork, (void **)&orig_fork);
    MSHookFunction((void *)system, (void *)hook_system, (void **)&orig_system);
    MSHookFunction((void *)dladdr, (void *)hook_dladdr, (void **)&orig_dladdr);
    
    NSLog(@"[QNByPass] Loaded OK!");
}
