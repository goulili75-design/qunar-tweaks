// QNByPass - ALS 参考全量版
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <errno.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <unistd.h>
#import <fcntl.h>
#import "substrate.h"

// 读配置
static NSDictionary *cfg(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"];
    return d ?: [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/.qnbypass.plist"] ?: @{};
}

static BOOL hookNo(id s, SEL c, ...) { return NO; }
static NSString *hookNil(id s, SEL c) { return nil; }

// ====== UIDevice ======
static NSUUID *(*orig_idfv)(id, SEL);
static NSUUID *hook_idfv(id s, SEL c) {
    NSString *u = cfg()[@"idfv"]; return u ? [[NSUUID alloc] initWithUUIDString:u] : orig_idfv(s, c);
}
static NSString *(*orig_devName)(id, SEL);
static NSString *hook_devName(id s, SEL c) { return @"iPhone"; }
static NSString *(*orig_devModel)(id, SEL);
static NSString *hook_devModel(id s, SEL c) { return @"iPhone"; }
static NSString *(*orig_sysVer)(id, SEL);
static NSString *hook_sysVer(id s, SEL c) { return @"16.0.3"; }

// ====== sysctl / uname ======
static int (*orig_sysctl)(int*,u_int,void*,size_t*,void*,size_t);
static int (*orig_sbn)(const char*,void*,size_t*,void*,size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (!n) return orig_sbn(n,o,ol,nw,nl);
    if (strcmp(n,"kern.bootargs")==0) { if(o&&ol)memset(o,0,*ol); errno=ENOENT; return -1; }
    NSString *m = cfg()[@"hwMachine"];
    if (m && strcmp(n,"hw.machine")==0 && o && ol) {
        const char *s=[m UTF8String]; size_t l=strlen(s)+1;
        if(*ol>=l){memcpy(o,s,l);*ol=l;return 0;}
    }
    return orig_sbn(n,o,ol,nw,nl);
}
static int (*orig_uname)(struct utsname *);
static int hook_uname(struct utsname *u) {
    int r = orig_uname(u);
    if (r == 0 && u) {
        strcpy(u->machine, "iPhone14,4");
        strcpy(u->nodename, "iPhone");
    }
    return r;
}

// ====== NSProcessInfo ======
static NSString *(*orig_hostName)(id, SEL);
static NSString *hook_hostName(id s, SEL c) { return @"iPhone"; }
static NSDictionary *(*orig_pe)(id, SEL);
static NSDictionary *hook_pe(id s, SEL c) {
    NSMutableDictionary *m = [orig_pe(s, c) mutableCopy];
    [m removeObjectForKey:@"DYLD_INSERT_LIBRARIES"]; [m removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return m;
}

// ====== NSFileManager ======
static BOOL (*orig_fep)(id, SEL, NSString *);
static BOOL hook_fep(id s, SEL c, NSString *p) {
    if (p && ([p hasPrefix:@"/var/jb"]||[p containsString:@"Cydia.app"]||[p containsString:@"Sileo.app"]||[p containsString:@"Dopamine.app"])) return NO;
    return orig_fep(s,c,p);
}

// ====== UIApplication URL ======
static BOOL (*orig_co)(id, SEL, NSURL *);
static BOOL hook_co(id s, SEL c, NSURL *u) {
    NSString *l=u.absoluteString.lowercaseString;
    if ([l hasPrefix:@"sileo:"]||[l hasPrefix:@"cydia:"]||[l hasPrefix:@"dopamine:"]||[l hasPrefix:@"zbra:"]||[l hasPrefix:@"filza:"]) return NO;
    return orig_co(s,c,u);
}

// ====== fork/stat/access (ALS同款) ======
static pid_t (*orig_f)(void);
static pid_t hook_f(void) { errno=EPERM; return -1; }
static int (*orig_stat)(const char*,struct stat*);
static int hook_stat(const char *p,struct stat *b) {
    if(p&&(strstr(p,"/var/jb")||strstr(p,"Cydia")||strstr(p,"Sileo"))){errno=ENOENT;return -1;}
    return orig_stat(p,b);
}
static int (*orig_access)(const char*,int);
static int hook_access(const char *p,int m) {
    if(p&&(strstr(p,"/var/jb")||strstr(p,"Cydia"))){errno=EACCES;return -1;}
    return orig_access(p,m);
}
static FILE *(*orig_fopen)(const char*,const char*);
static FILE *hook_fopen(const char *p,const char *m) {
    if(p&&(strstr(p,"/var/jb")||strstr(p,"Cydia"))){errno=ENOENT;return NULL;}
    return orig_fopen(p,m);
}

// ====== VPN/代理检测 (ALS同款) ======
static CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void);
static CFDictionaryRef hook_CFNetworkCopySystemProxySettings(void) {
    return NULL; // 返回 NULL = 无代理
}
static void *(*orig_NEVPNConnection)(void);
static void hook_NEVPNConnection(void) {} // 禁用VPN检测

// ====== Constructor ======
__attribute__((constructor))
static void init(void) {
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if (![proc isEqualToString:@"QunariPhone_Cook_CM"]) return;
    NSLog(@"[QNByPass] Loading vFinal...");
    
    Class uid = NSClassFromString(@"UIDevice");
    if (uid) {
        SEL sl[]={@selector(isJailbroken),@selector(isJailBreak),@selector(isJailBroken),@selector(isDeviceJailbroken),@selector(checkJailbroken)};
        for(int i=0;i<sizeof(sl)/sizeof(SEL);i++){Method m=class_getInstanceMethod(uid,sl[i]);if(m)class_replaceMethod(uid,sl[i],(IMP)hookNo,method_getTypeEncoding(m));}
        MSHookMessageEx(uid,@selector(identifierForVendor),(IMP)hook_idfv,(IMP*)&orig_idfv);
        MSHookMessageEx(uid,@selector(name),(IMP)hook_devName,(IMP*)&orig_devName);
        MSHookMessageEx(uid,@selector(model),(IMP)hook_devModel,(IMP*)&orig_devModel);
        MSHookMessageEx(uid,@selector(systemVersion),(IMP)hook_sysVer,(IMP*)&orig_sysVer);
    }
    MSHookMessageEx(NSClassFromString(@"NSFileManager"),@selector(fileExistsAtPath:),(IMP)hook_fep,(IMP*)&orig_fep);
    MSHookMessageEx(NSClassFromString(@"UIApplication"),@selector(canOpenURL:),(IMP)hook_co,(IMP*)&orig_co);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"),@selector(hostName),(IMP)hook_hostName,(IMP*)&orig_hostName);
    MSHookMessageEx(NSClassFromString(@"NSProcessInfo"),@selector(environment),(IMP)hook_pe,(IMP*)&orig_pe);
    
    MSHookFunction((void*)sysctl,(void*)hook_sysctl,(void**)&orig_sysctl);
    MSHookFunction((void*)sysctlbyname,(void*)hook_sbn,(void**)&orig_sbn);
    MSHookFunction((void*)uname,(void*)hook_uname,(void**)&orig_uname);
    MSHookFunction((void*)fork,(void*)hook_f,(void**)&orig_f);
    MSHookFunction((void*)stat,(void*)hook_stat,(void**)&orig_stat);
    MSHookFunction((void*)access,(void*)hook_access,(void**)&orig_access);
    MSHookFunction((void*)fopen,(void*)hook_fopen,(void**)&orig_fopen);
    MSHookFunction((void*)CFNetworkCopySystemProxySettings,(void*)hook_CFNetworkCopySystemProxySettings,(void**)&orig_CFNetworkCopySystemProxySettings);
    
    NSLog(@"[QNByPass] All hooks active!");
}
