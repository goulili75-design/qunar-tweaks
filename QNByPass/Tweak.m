// QNByPass - 越狱屏蔽 + 改机 (完整版)
// 越狱检测绕过 + 设备信息伪装
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import "substrate.h"

// ============ 改机配置（持久化到文件） ============
static NSString *configPath(void) {
    return @"/var/jb/var/mobile/Documents/.qnbypass_config.plist";
}

static NSDictionary *loadConfig(void) {
    return [NSDictionary dictionaryWithContentsOfFile:configPath()] ?: @{};
}

static BOOL isEnabled(void) {
    return [loadConfig()[@"enabled"] boolValue];
}

// ============ ObjC Hooks ============

static BOOL hookNo(id s, SEL c, ...) { return NO; }

// --- NSFileManager ---
static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id s, SEL c, NSString *p) {
    if (p && ([p hasPrefix:@"/var/jb"] || [p hasPrefix:@"/Library/MobileSubstrate"] ||
              [p containsString:@"Cydia.app"] || [p containsString:@"Sileo.app"] ||
              [p containsString:@"Dopamine.app"] || [p containsString:@"frida"])) return NO;
    return orig_fep(s, c, p);
}

// --- UIApplication ---
static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id s, SEL c, NSURL *u) {
    NSString *str = u.absoluteString.lowercaseString;
    if ([str hasPrefix:@"sileo:"] || [str hasPrefix:@"cydia:"] || 
        [str hasPrefix:@"dopamine:"] || [str hasPrefix:@"filza:"]) return NO;
    return orig_co(s, c, u);
}

// --- NSProcessInfo ---
static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id s, SEL c) {
    NSMutableDictionary *m = [orig_pe(s, c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}

// --- 改机：UIDevice 伪装 ---
static NSUUID *(*orig_idfv)(id, SEL);
static NSUUID *hook_idfv(id s, SEL c) {
    if (isEnabled()) {
        NSDictionary *cfg = loadConfig();
        NSString *uuid = cfg[@"idfv"] ?: @"E621E1F8-C36C-495A-93FC-0C247A3E6E5F";
        return [[NSUUID alloc] initWithUUIDString:uuid];
    }
    return orig_idfv(s, c);
}

static NSString *(*orig_name)(id, SEL);
static NSString *hook_name(id s, SEL c) {
    return isEnabled() ? (loadConfig()[@"deviceName"] ?: @"iPhone") : orig_name(s, c);
}

static NSString *(*orig_model)(id, SEL);
static NSString *hook_model(id s, SEL c) {
    return isEnabled() ? (loadConfig()[@"model"] ?: @"iPhone") : orig_model(s, c);
}

// --- 改机：sysctl 伪装 ---
static int (*orig_sbn)(const char *, void *, size_t *, void *, size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    // 越狱检测 → 返回错误
    if (n && (strcmp(n,"kern.bootargs")==0 || strstr(n,"security.mac."))) {
        if (o && ol) memset(o, 0, *ol);
        errno = ENOENT; return -1;
    }
    // 改机：伪装设备型号
    if (isEnabled() && n) {
        if (strcmp(n, "hw.machine") == 0 || strcmp(n, "hw.model") == 0) {
            if (o && ol) {
                const char *fake = "iPhone14,4"; // iPhone 12 mini (接近你的设备但不同)
                size_t len = strlen(fake) + 1;
                if (*ol >= len) {
                    strcpy((char *)o, fake);
                    *ol = len;
                    return 0;
                }
            }
        }
        if (strcmp(n, "hw.ncpu") == 0 || strcmp(n, "hw.physicalcpu") == 0) {
            if (o && ol && *ol >= sizeof(int)) { *(int *)o = 6; *ol = sizeof(int); return 0; }
        }
    }
    return orig_sbn(n, o, ol, nw, nl);
}

// --- C 函数 ---
static pid_t (*orig_fork)(void);
static pid_t hook_fork(void) { errno = EPERM; return -1; }

static int (*orig_system)(const char *);
static int hook_system(const char *c) { errno = EPERM; return -1; }

// ============ Constructor ============
__attribute__((constructor))
static void qnbypass_init(void) {
    NSLog(@"[QNByPass] Loading... enabled=%d", isEnabled());
    if (!isEnabled()) { NSLog(@"[QNByPass] Not enabled, skipping hooks"); return; }
    
    // UIDevice - 越狱检测
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
        for (int i=0;i<sizeof(sl)/sizeof(SEL);i++) { Method m=class_getInstanceMethod(c,sl[i]); if(m)class_replaceMethod(c,sl[i],(IMP)hookNo,method_getTypeEncoding(m)); }
        
        // 改机 Hook
        MSHookMessageEx(c, @selector(identifierForVendor), (IMP)hook_idfv, (IMP*)&orig_idfv);
        MSHookMessageEx(c, @selector(name), (IMP)hook_name, (IMP*)&orig_name);
        MSHookMessageEx(c, @selector(model), (IMP)hook_model, (IMP*)&orig_model);
    }
    
    // ObjC hooks
    MSHookMessageEx(NSClassFromString(@"NSFileManager"),@selector(fileExistsAtPath:),(IMP)hook_fep,(IMP*)&orig_fep);
    MSHookMessageEx(NSClassFromString(@"UIApplication"),@selector(canOpenURL:),(IMP)hook_co,(IMP*)&orig_co);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"),@selector(environment),(IMP)hook_pe,(IMP*)&orig_pe);
    
    // C hooks
    MSHookFunction((void *)sysctlbyname, (void *)hook_sbn, (void **)&orig_sbn);
    MSHookFunction((void *)fork, (void *)hook_fork, (void **)&orig_fork);
    MSHookFunction((void *)system, (void *)hook_system, (void **)&orig_system);
    
    NSLog(@"[QNByPass] All hooks active!");
}
