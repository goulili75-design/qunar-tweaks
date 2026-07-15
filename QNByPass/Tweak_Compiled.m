// QNByPass v10 - 终极版：CTT + Header + Cookie + 越狱屏蔽
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <fcntl.h>
#import <dlfcn.h>
#import "substrate.h"

static NSDictionary *loadCfg(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"];
    return d ?: [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/.qnbypass.plist"];
}

static BOOL hookNo(id s, SEL c, ...) { return NO; }

// 改机：IDFV
static NSUUID *(*orig_idfv)(id, SEL);
static NSUUID *hook_idfv(id s, SEL c) {
    NSString *uuid = loadCfg()[@"idfv"];
    return uuid ? [[NSUUID alloc] initWithUUIDString:uuid] : orig_idfv(s, c);
}
// 改机：设备型号
static int (*orig_sbn)(const char *, void *, size_t *, void *, size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (n && strcmp(n, "kern.bootargs") == 0) { if (o && ol) memset(o, 0, *ol); errno = ENOENT; return -1; }
    if (n && strcmp(n, "hw.machine") == 0) {
        NSString *m = loadCfg()[@"hwMachine"];
        if (m && o && ol) { const char *s = [m UTF8String]; size_t l = strlen(s)+1;
            if (*ol >= l) { memcpy(o, s, l); *ol = l; return 0; } }
    }
    return orig_sbn(n, o, ol, nw, nl);
}
// 文件检测——拦截所有越狱 App 路径
static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id s, SEL c, NSString *p) {
    if (p) {
        if ([p hasPrefix:@"/var/jb"]) return NO;
        if ([p containsString:@"Cydia.app"] || [p containsString:@"Sileo.app"] ||
            [p containsString:@"Dopamine.app"] || [p containsString:@"Zebra.app"] ||
            [p containsString:@"Filza.app"] || [p containsString:@"TrollStore.app"] ||
            [p containsString:@"Activator.app"] || [p containsString:@"iCleaner.app"] ||
            [p containsString:@"NewTerm.app"] || [p containsString:@"Santander.app"])
            return NO;
    }
    return orig_fep(s, c, p);
}
// URL Scheme 检测——防 Qunar 扫描所有越狱 App
static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id s, SEL c, NSURL *u) {
    NSString *l = u.absoluteString.lowercaseString;
    if ([l hasPrefix:@"sileo:"] || [l hasPrefix:@"cydia:"] || [l hasPrefix:@"dopamine:"] ||
        [l hasPrefix:@"zbra:"] || [l hasPrefix:@"undecimus:"] || [l hasPrefix:@"filza:"] ||
        [l hasPrefix:@"activator:"] || [l hasPrefix:@"jbroot:"] || [l hasPrefix:@"apt-repo:"] ||
        [l hasPrefix:@"xina:"] || [l hasPrefix:@"postbox:"] || [l hasPrefix:@"icleaner:"] ||
        [l hasPrefix:@"santander:"] || [l hasPrefix:@"ssh:"]) return NO;
    return orig_co(s, c, u);
}
// 环境变量
static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id s, SEL c) {
    NSMutableDictionary *m = [orig_pe(s, c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"]; [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}
// fork 沙箱检测
static pid_t (*orig_f)(void);
static pid_t hook_f(void) { errno = EPERM; return -1; }

// NSComparisonPredicate 短路——防 iOS16 "借刀杀人" 检测
static BOOL (*orig_predEval)(id, SEL, id, id);
static BOOL hook_predEval(id self, SEL _cmd, id obj, id vars) {
    return NO;
}

// === v10：运营商伪装（返回 nil = 无SIM卡） ===
static id (*orig_subCarrier)(id, SEL);
static id hook_subCarrier(id self, SEL _cmd) {
    return nil; // 返回 nil，隐藏运营商信息
}

// === v10：NSMutableURLRequest Header 过滤 ===
static void (*orig_setValue)(id, SEL, NSString*, NSString*);
static void hook_setValue(id self, SEL _cmd, NSString *value, NSString *field) {
    if (field && [field hasPrefix:@"Q-"]) return;
    orig_setValue(self, _cmd, value, field);
}

// === v10：Cookie 清理 ===
static NSArray *(*orig_cookies)(id, SEL);
static NSArray *hook_cookies(id self, SEL _cmd) {
    NSArray *all = orig_cookies(self, _cmd);
    NSMutableArray *filtered = [NSMutableArray array];
    for (id c in all) {
        NSString *name = [c valueForKey:@"name"];
        NSString *domain = [c valueForKey:@"domain"];
        if ([name hasPrefix:@"QN"] && [domain containsString:@"qunar"]) continue;
        [filtered addObject:c];
    }
    return filtered;
}

__attribute__((constructor))
static void init(void) {
    NSLog(@"[QNByPass] Loading for Qunar...");
    
    Class c = NSClassFromString(@"UIDevice");
    if (c) {
        SEL sl[] = {
            @selector(isJailbroken),@selector(isJailBreak),@selector(isJailBroken),
            @selector(isDeviceJailbroken),@selector(checkJailbroken),@selector(isJailBrokenDevice),
            @selector(isCydiaJailBreak),@selector(isPathJailBreak),@selector(isJailBreak_appList),
            @selector(isJailBreak_cydia),@selector(isJailBreak_file),@selector(isJailBreak_env),
            @selector(isJailBreakByEnv),@selector(isJailBreakByStat),@selector(isJailbreak),
            @selector(isRootedOrJailbroken),@selector(o_pay_sdk_isJail),@selector(boolIsjailbreak),
            @selector(computeIsJailbroken),@selector(jailBrokenJudge)
        };
        for (int i=0; i<sizeof(sl)/sizeof(SEL); i++) {
            Method m = class_getInstanceMethod(c, sl[i]);
            if (m) class_replaceMethod(c, sl[i], (IMP)hookNo, method_getTypeEncoding(m));
        }
        MSHookMessageEx(c, @selector(identifierForVendor), (IMP)hook_idfv, (IMP*)&orig_idfv);
    }
    
    MSHookMessageEx(NSClassFromString(@"NSFileManager"), @selector(fileExistsAtPath:), (IMP)hook_fep, (IMP*)&orig_fep);
    MSHookMessageEx(NSClassFromString(@"UIApplication"), @selector(canOpenURL:), (IMP)hook_co, (IMP*)&orig_co);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"), @selector(environment), (IMP)hook_pe, (IMP*)&orig_pe);
    
    MSHookFunction((void *)sysctlbyname, (void *)hook_sbn, (void **)&orig_sbn);
    MSHookFunction((void *)fork, (void *)hook_f, (void **)&orig_f);
    
    // NSComparisonPredicate 短路防护（FanDuel 同款）
    MSHookMessageEx(NSClassFromString(@"NSComparisonPredicate"), @selector(evaluateWithObject:substitutionVariables:), (IMP)hook_predEval, (IMP*)&orig_predEval);
    
    // v10 新增：Cookie 清理
    MSHookMessageEx(NSClassFromString(@"NSHTTPCookieStorage"), @selector(cookies), (IMP)hook_cookies, (IMP*)&orig_cookies);
    
    NSLog(@"[QNByPass] All hooks active! (v10)");
}
