// QNByPass - 越狱屏蔽 + 设备改机 (vFinal)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <fcntl.h>
#import "substrate.h"

static NSDictionary *loadCfg(void) {
    return [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"] ?:
           [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/.qnbypass.plist"];
}

static BOOL hookNo(id s, SEL c, ...) { return NO; }

// === 改机：IDFV 伪装 ===
static NSUUID *(*orig_idfv)(id, SEL);
static NSUUID *hook_idfv(id s, SEL c) {
    NSString *uuid = loadCfg()[@"idfv"];
    if (uuid) return [[NSUUID alloc] initWithUUIDString:uuid];
    return orig_idfv(s, c);
}
// === 改机：设备型号 hw.machine ===
static int (*orig_sbn)(const char *, void *, size_t *, void *, size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (n && strcmp(n, "kern.bootargs") == 0) { if (o && ol) memset(o, 0, *ol); errno = ENOENT; return -1; }
    if (n && strcmp(n, "hw.machine") == 0) {
        NSString *m = loadCfg()[@"hwMachine"];
        if (m && o && ol) {
            const char *s = [m UTF8String]; size_t l = strlen(s)+1;
            if (*ol >= l) { memcpy(o, s, l); *ol = l; return 0; }
        }
    }
    return orig_sbn(n, o, ol, nw, nl);
}

static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id s, SEL c, NSString *p) {
    if (p && ([p hasPrefix:@"/var/jb"] || [p containsString:@"Cydia.app"] || [p containsString:@"Sileo.app"])) return NO;
    return orig_fep(s, c, p);
}
static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id s, SEL c, NSURL *u) {
    NSString *l = u.absoluteString.lowercaseString;
    if ([l hasPrefix:@"sileo:"] || [l hasPrefix:@"cydia:"] || [l hasPrefix:@"dopamine:"]) return NO;
    return orig_co(s, c, u);
}
static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id s, SEL c) {
    NSMutableDictionary *m = [orig_pe(s, c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"]; [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}
static pid_t (*orig_f)(void);
static pid_t hook_f(void) { errno = EPERM; return -1; }

__attribute__((constructor))
static void init(void) {
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if (![proc isEqualToString:@"QunariPhone_Cook_CM"]) return;
    
    Class c = NSClassFromString(@"UIDevice");
    if (c) {
        SEL sl[] = { @selector(isJailbroken),@selector(isJailBreak),@selector(isJailBroken),@selector(isDeviceJailbroken) };
        for (int i=0; i<sizeof(sl)/sizeof(SEL); i++) { Method m=class_getInstanceMethod(c,sl[i]); if(m)class_replaceMethod(c,sl[i],(IMP)hookNo,method_getTypeEncoding(m)); }
        MSHookMessageEx(c, @selector(identifierForVendor), (IMP)hook_idfv, (IMP*)&orig_idfv);
    }
    MSHookMessageEx(NSClassFromString(@"NSFileManager"), @selector(fileExistsAtPath:), (IMP)hook_fep, (IMP*)&orig_fep);
    MSHookMessageEx(NSClassFromString(@"UIApplication"), @selector(canOpenURL:), (IMP)hook_co, (IMP*)&orig_co);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"), @selector(environment), (IMP)hook_pe, (IMP*)&orig_pe);
    MSHookFunction((void *)sysctlbyname, (void *)hook_sbn, (void **)&orig_sbn);
    MSHookFunction((void *)fork, (void *)hook_f, (void **)&orig_f);
    
    // 诊断：写日志
    NSString *log = [NSString stringWithFormat:@"%@ QNByPass LOADED | IDFV=%@ | HW=%@\n",
                     [NSDate date], loadCfg()[@"idfv"]?:@"original", loadCfg()[@"hwMachine"]?:@"original"];
    [log writeToFile:@"/var/jb/var/mobile/Documents/.qnlog.txt" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}
