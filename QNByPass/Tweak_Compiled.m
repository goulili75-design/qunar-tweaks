// QNByPass Pro - 商业改机级别参数伪装
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

// ── 随机池 ──
static char *randHw(void) {
    static char b[32]; static const char *m[] = {
        "iPhone14,4","iPhone14,5","iPhone14,2","iPhone14,3",
        "iPhone13,2","iPhone13,3","iPhone13,4","iPhone12,1",
        "iPhone12,3","iPhone12,5","iPhone14,7","iPhone15,2"};
    snprintf(b,sizeof(b),"%s",m[arc4random_uniform(12)]); return b;
}
static char *randOS(void) {
    static char b[16]; static const char *v[] = {
        "16.0.2","16.0.3","16.1","16.1.1","16.1.2","16.2",
        "16.3","16.3.1","16.4","16.4.1","16.5","16.5.1","16.6"};
    snprintf(b,sizeof(b),"%s",v[arc4random_uniform(13)]); return b;
}
static NSString *randUUID(void) { return [[NSUUID UUID] UUIDString]; }
static NSString *randIDFA(void) {
    return [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""].uppercaseString;
}
static NSString *randSSID(void) {
    NSArray *ssids = @[@"CMCC-5G",@"ChinaNet-WiFi",@"TP-LINK_5G",@"iPhone",@"HUAWEI-WiFi",@"Xiaomi_Home"];
    return ssids[arc4random_uniform((uint32_t)ssids.count)];
}
static NSString *randBSSID(void) {
    return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
            arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),
            arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256)];
}
static NSString *randCarrier(void) {
    NSArray *c = @[@"中国移动",@"中国联通",@"中国电信",@"中国广电"];
    return c[arc4random_uniform(4)];
}
static NSString *randMCC(void) {
    NSArray *m = @[@"46000",@"46001",@"46003",@"46011"];
    return m[arc4random_uniform(4)];
}
static NSString *randMNC(void) {
    NSArray *m = @[@"02",@"01",@"03",@"07"];
    return m[arc4random_uniform(4)];
}
static long long randDisk(void) { return 50000000000LL + arc4random_uniform(30000000000LL); }
static long long randFree(void) { return 10000000000LL + arc4random_uniform(20000000000LL); }
static CGFloat randBrightness(void) { return 0.3f + (float)arc4random_uniform(500)/1000.0f; }
static NSString *randLocale(void) {
    return ((NSArray*)@[@"zh_CN",@"en_US"])[arc4random_uniform(2)];
}
static NSString *randTZ(void) {
    return ((NSArray*)@[@"Asia/Shanghai",@"Asia/Hong_Kong"])[arc4random_uniform(2)];
}

// ── fishhook ──
static int fishhook(const char *sym, void *rep, void **orig) {
    struct { const char *n; void *r; void **o; } rb = {sym,rep,orig};
    static int (*f)(void) = NULL;
    if (!f) { void *h=dlopen(NULL,RTLD_LAZY); f=dlsym(h,"rebind_symbols"); dlclose(h); }
    return f ? ((int(*)(void*,size_t))f)(&rb,1) : -1;
}

// ── C hooks ──
static int (*orig_sbn)(const char*,void*,size_t*,void*,size_t);
static int hook_sbn(const char *n, void *o, size_t *ol, void *nw, size_t nl) {
    if (!n||!o||!ol) return orig_sbn?orig_sbn(n,o,ol,nw,nl):-1;
    if (!strcmp(n,"hw.machine")||!strcmp(n,"hw.model")) {
        char *s=randHw();size_t l=strlen(s)+1;if(*ol>=l){memcpy(o,s,l);*ol=l;return 0;}
    }
    if (!strncmp(n,"hw.",3)) return orig_sbn?orig_sbn(n,o,ol,nw,nl):-1;
    if (!strcmp(n,"kern.bootargs")){memset(o,0,*ol);errno=ENOENT;return -1;}
    return orig_sbn?orig_sbn(n,o,ol,nw,nl):-1;
}

static int (*orig_sysctl)(int*,u_int,void*,size_t*,void*,size_t);
static int hook_sysctl(int *n,u_int nl,void*o,size_t*ol,void*x,size_t xl){
    return orig_sysctl?orig_sysctl(n,nl,o,ol,x,xl):-1;
}

static int (*orig_uname)(struct utsname*);
static int hook_uname(struct utsname *u){
    int r=orig_uname?orig_uname(u):0;
    if(r==0&&u){strcpy(u->machine,randHw());strcpy(u->nodename,"iPhone");}
    return r;
}

// ── 安装 Hook ──
static void install(void) {
    // UIDevice
    Class c=NSClassFromString(@"UIDevice");
    if(c){SEL s[]={@selector(identifierForVendor),@selector(name),@selector(model),@selector(systemVersion)};IMP(*b[])={^NSUUID*{return[[NSUUID alloc]initWithUUIDString:randUUID()];},^NSString*{return @"iPhone";},^NSString*{return @"iPhone";},^NSString*{return @(randOS());}};for(int i=0;i<4;i++){Method m=class_getInstanceMethod(c,s[i]);if(m)method_setImplementation(m,imp_implementationWithBlock((id)b[i]));}}

    // NSProcessInfo
    c=NSClassFromString(@"NSProcessInfo");
    if(c){Method m=class_getInstanceMethod(c,@selector(environment));if(m){IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^NSDictionary*(id s){NSMutableDictionary*e=[((NSDictionary*(*)(id,SEL))old)(s,@selector(environment))mutableCopy];[e removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];[e removeObjectForKey:@"DYLD_LIBRARY_PATH"];return e;}));}SEL s[]={@selector(hostName),@selector(physicalMemory),@selector(processorCount)};IMP(*b[])={^NSString*{return @"iPhone";},^unsigned long long{return 4000000000ULL;},^NSUInteger{return 6;}};for(int i=0;i<3;i++){m=class_getInstanceMethod(c,s[i]);if(m)method_setImplementation(m,imp_implementationWithBlock((id)b[i]));}}

    // NSFileManager (磁盘空间)
    c=NSClassFromString(@"NSFileManager");
    if(c){SEL s[]={@selector(attributesOfFileSystemForPath:error:)};Method m=class_getInstanceMethod(c,@selector(attributesOfFileSystemForPath:error:));if(m){IMP old=(IMP)NULL;class_getMethodImplementation(c,@selector(attributesOfFileSystemForPath:error:));}}

    // NSLocale / NSTimeZone
    c=NSClassFromString(@"NSLocale");if(c){Method m=class_getInstanceMethod(c,@selector(localeIdentifier));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return randLocale();}));m=class_getInstanceMethod(c,@selector(countryCode));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return @"CN";}));}
    c=NSClassFromString(@"NSTimeZone");if(c){Method m=class_getInstanceMethod(c,@selector(name));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return randTZ();}));}

    // UIScreen
    c=NSClassFromString(@"UIScreen");if(c){Method m=class_getInstanceMethod(c,@selector(brightness));if(m)method_setImplementation(m,imp_implementationWithBlock(^CGFloat{return randBrightness();}));}

    // ASIdentifierManager (IDFA)
    c=NSClassFromString(@"ASIdentifierManager");if(c){Method m=class_getInstanceMethod(c,@selector(advertisingIdentifier));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSUUID*{return[[NSUUID alloc]initWithUUIDString:randIDFA()];}));}

    // CTTelephonyNetworkInfo
    c=NSClassFromString(@"CTTelephonyNetworkInfo");if(c){Method m=class_getInstanceMethod(c,@selector(subscriberCellularProvider));if(m)method_setImplementation(m,imp_implementationWithBlock(^id(id s){return nil;}));}

    // NSBundle
    c=NSClassFromString(@"NSBundle");if(c){Method m=class_getInstanceMethod(c,@selector(bundleIdentifier));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return @"com.qunar.iphoneclient";}));}

    // C hooks
    fishhook("sysctlbyname",hook_sbn,(void**)&orig_sbn);
    fishhook("sysctl",hook_sysctl,(void**)&orig_sysctl);
    fishhook("uname",hook_uname,(void**)&orig_uname);

    [[NSString stringWithFormat:@"[QNByPass] PRO loaded | HW=%s | IDFV=%@",randHw(),randUUID()]
     writeToFile:@"/var/jb/var/mobile/Documents/.qnpro.txt" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

__attribute__((constructor))
static void init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC),dispatch_get_main_queue(),^{install();});
}
