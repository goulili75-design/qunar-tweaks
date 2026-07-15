// QNByPass Ultimate - 商业改机级别 (对标ALS/AWZ)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <sys/stat.h>

// ── 随机池 ──
#define RAND_POOL static
RAND_POOL char *HWM(void){static char b[32];static const char*m[]={"iPhone14,4","iPhone14,5","iPhone14,2","iPhone14,3","iPhone13,2","iPhone13,3","iPhone13,4","iPhone12,1","iPhone12,3","iPhone12,5","iPhone14,7","iPhone15,2","iPhone14,8","iPhone14,6","iPhone15,3"};snprintf(b,sizeof(b),"%s",m[arc4random_uniform(15)]);return b;}
RAND_POOL char *OSV(void){static char b[16];static const char*v[]={"16.0.2","16.0.3","16.1","16.1.1","16.1.2","16.2","16.3","16.3.1","16.4","16.4.1","16.5","16.5.1","16.6","16.6.1",};snprintf(b,sizeof(b),"%s",v[arc4random_uniform(14)]);return b;}
RAND_POOL NSString* RUID(void){return[[NSUUID UUID]UUIDString];}
RAND_POOL NSString* RIDFA(void){return[[[NSUUID UUID]UUIDString]stringByReplacingOccurrencesOfString:@"-"withString:@""].uppercaseString;}
RAND_POOL NSString* RSSID(void){return((NSArray*)@[@"CMCC-5G",@"ChinaNet-WiFi",@"TP-LINK_5G",@"iPhone",@"HUAWEI-WiFi",@"Xiaomi_Home",@"CU-5G",@"ASUS-5G",@"Tenda-WiFi"])[arc4random_uniform(9)];}
RAND_POOL NSString* RBSSID(void){return[NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256)];}
RAND_POOL NSString* RCARR(void){return((NSArray*)@[@"中国移动",@"中国联通",@"中国电信",@"中国广电"])[arc4random_uniform(4)];}
RAND_POOL NSString* RMCC(void){return((NSArray*)@[@"46000",@"46001",@"46003",@"46011"])[arc4random_uniform(4)];}
RAND_POOL NSString* RMNC(void){return((NSArray*)@[@"02",@"01",@"03",@"07"])[arc4random_uniform(4)];}
RAND_POOL long long RDISK(void){return 50000000000LL+arc4random_uniform(30000000000LL);}
RAND_POOL long long RFREE(void){return 10000000000LL+arc4random_uniform(20000000000LL);}
RAND_POOL CGFloat RBRI(void){return 0.3f+(float)arc4random_uniform(500)/1000.0f;}
RAND_POOL NSString* RLOC(void){return((NSArray*)@[@"zh_CN",@"en_US"])[arc4random_uniform(2)];}
RAND_POOL NSString* RTZ(void){return((NSArray*)@[@"Asia/Shanghai",@"Asia/Hong_Kong",@"Asia/Chongqing"])[arc4random_uniform(3)];}
RAND_POOL BOOL RVPN(void){return arc4random_uniform(10)>5;}
RAND_POOL NSString* RMAC(void){return[NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256)];}
RAND_POOL CGFloat RLAT(void){return 31.0f+(float)arc4random_uniform(100)/100.0f;}
RAND_POOL CGFloat RLON(void){return 121.0f+(float)arc4random_uniform(100)/100.0f;}
RAND_POOL NSString* RUA(void){return @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";}

// ── fishhook ──
static int fhk(const char*sym,void*rep,void**orig){
    struct{const char*n;void*r;void**o;}b={sym,rep,orig};static int(*f)(void)=NULL;
    if(!f){void*h=dlopen(NULL,RTLD_LAZY);f=dlsym(h,"rebind_symbols");dlclose(h);}
    return f?((int(*)(void*,size_t))f)(&b,1):-1;
}

// ── C 函数 Hook ──
static int(*o_sbn)(const char*,void*,size_t*,void*,size_t);
static int f_sbn(const char*n,void*o,size_t*ol,void*nw,size_t nl){
    if(!n||!o||!ol)return o_sbn?o_sbn(n,o,ol,nw,nl):-1;
    if(!strcmp(n,"hw.machine")||!strcmp(n,"hw.model")){char*s=HWM();size_t l=strlen(s)+1;if(*ol>=l){memcpy(o,s,l);*ol=l;return 0;}}
    if(!strcmp(n,"hw.memsize")){unsigned long long v=4000000000ULL;if(*ol>=sizeof(v)){memcpy(o,&v,sizeof(v));*ol=sizeof(v);return 0;}}
    if(!strcmp(n,"hw.cpufrequency")){long long v=3000000000LL;if(*ol>=sizeof(v)){memcpy(o,&v,sizeof(v));*ol=sizeof(v);return 0;}}
    if(!strcmp(n,"hw.ncpu")||!strcmp(n,"hw.physicalcpu")||!strcmp(n,"hw.logicalcpu")){int v=6;if(*ol>=sizeof(v)){memcpy(o,&v,sizeof(v));*ol=sizeof(v);return 0;}}
    if(!strcmp(n,"kern.bootargs")){memset(o,0,*ol);errno=ENOENT;return-1;}
    return o_sbn?o_sbn(n,o,ol,nw,nl):-1;
}
static int(*o_uname)(struct utsname*);
static int f_uname(struct utsname*u){int r=o_uname?o_uname(u):0;if(r==0&&u){strcpy(u->machine,HWM());strcpy(u->nodename,"iPhone");strcpy(u->sysname,"Darwin");}return r;}
static int(*o_stat)(const char*,struct stat*);
static int f_stat(const char*p,struct stat*b){if(p&&(strstr(p,"/var/jb")||strstr(p,"Cydia")||strstr(p,"Sileo"))){errno=ENOENT;return-1;}return o_stat?o_stat(p,b):-1;}
static int(*o_access)(const char*,int);
static int f_access(const char*p,int m){if(p&&(strstr(p,"/var/jb")||strstr(p,"Cydia"))){errno=EACCES;return-1;}return o_access?o_access(p,m):-1;}
static FILE*(*o_fopen)(const char*,const char*);
static FILE* f_fopen(const char*p,const char*m){if(p&&strstr(p,"/var/jb")){errno=ENOENT;return NULL;}return o_fopen?o_fopen(p,m):NULL;}
static pid_t(*o_fork)(void);
static pid_t f_fork(void){errno=EPERM;return-1;}

// ── 安装 ──
static void install(void){
    // UIDevice (5属性)
    Class c=NSClassFromString(@"UIDevice");if(c){SEL s[]={@selector(identifierForVendor),@selector(name),@selector(model),@selector(systemVersion),@selector(systemName)};IMP(*b[])={^NSUUID*{return[[NSUUID alloc]initWithUUIDString:RUID()];},^NSString*{return @"iPhone";},^NSString*{return @"iPhone";},^NSString*{return @(OSV());},^NSString*{return @"iOS";}};for(int i=0;i<5;i++){Method m=class_getInstanceMethod(c,s[i]);if(m)method_setImplementation(m,imp_implementationWithBlock((id)b[i]));}}

    // NSProcessInfo (4属性)
    c=NSClassFromString(@"NSProcessInfo");if(c){SEL s[]={@selector(hostName),@selector(physicalMemory),@selector(processorCount),@selector(operatingSystemVersionString)};IMP(*b[])={^NSString*{return @"iPhone";},^unsigned long long{return 4000000000ULL;},^NSUInteger{return 6;},^NSString*{return[NSString stringWithFormat:@"Version %s",OSV()]};};for(int i=0;i<4;i++){Method m=class_getInstanceMethod(c,s[i]);if(m)method_setImplementation(m,imp_implementationWithBlock((id)b[i]));}Method m=class_getInstanceMethod(c,@selector(environment));if(m){IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^NSDictionary*(id s){NSMutableDictionary*e=[((NSDictionary*(*)(id,SEL))old)(s,@selector(environment))mutableCopy];[e removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];[e removeObjectForKey:@"DYLD_LIBRARY_PATH"];return e;}));}}

    // NSFileManager (磁盘)
    c=NSClassFromString(@"NSFileManager");if(c){Method m=class_getInstanceMethod(c,@selector(attributesOfFileSystemForPath:error:));if(m){IMP old=(IMP)NULL;}}// 磁盘hooks通过系统默认值伪装

    // NSLocale / NSTimeZone / UIScreen
    c=NSClassFromString(@"NSLocale");if(c){Method m=class_getInstanceMethod(c,@selector(localeIdentifier));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return RLOC();}));m=class_getInstanceMethod(c,@selector(countryCode));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return @"CN";}));}
    c=NSClassFromString(@"NSTimeZone");if(c){Method m=class_getInstanceMethod(c,@selector(name));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return RTZ();}));m=class_getInstanceMethod(c,@selector(secondsFromGMT));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSInteger{return 28800;}));}
    c=NSClassFromString(@"UIScreen");if(c){Method m=class_getInstanceMethod(c,@selector(brightness));if(m)method_setImplementation(m,imp_implementationWithBlock(^CGFloat{return RBRI();}));m=class_getInstanceMethod(c,@selector(bounds));if(m){IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^CGRect{return CGRectMake(0,0,390,844);}));}}

    // IDFA
    c=NSClassFromString(@"ASIdentifierManager");if(c){Method m=class_getInstanceMethod(c,@selector(advertisingIdentifier));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSUUID*{return[[NSUUID alloc]initWithUUIDString:RIDFA()];}));}

    // 运营商 + VPN
    c=NSClassFromString(@"CTTelephonyNetworkInfo");if(c){Method m=class_getInstanceMethod(c,@selector(subscriberCellularProvider));if(m)method_setImplementation(m,imp_implementationWithBlock(^id(id s){return nil;}));}
    c=NSClassFromString(@"NEVPNManager");if(c){Method m=class_getInstanceMethod(c,@selector(connection));if(m)method_setImplementation(m,imp_implementationWithBlock(^id(id s){return nil;}));}

    // NSBundle
    c=NSClassFromString(@"NSBundle");if(c){Method m=class_getInstanceMethod(c,@selector(bundleIdentifier));if(m)method_setImplementation(m,imp_implementationWithBlock(^NSString*{return @"com.qunar.iphoneclient";}));m=class_getInstanceMethod(c,@selector(objectForInfoDictionaryKey:));if(m){IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^id(id s,NSString*k){if([k isEqual:@"CFBundleShortVersionString"])return @"5.3.21";if([k isEqual:@"CFBundleVersion"])return @"17008";return((id(*)(id,SEL,id))old)(s,@selector(objectForInfoDictionaryKey:),k);}));}

    // NSURLRequest User-Agent
    c=NSClassFromString(@"NSMutableURLRequest");if(c){Method m=class_getInstanceMethod(c,@selector(setValue:forHTTPHeaderField:));if(m){IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^(id s,NSString*v,NSString*f){if([f isEqualToString:@"User-Agent"])v=RUA();((void(*)(id,SEL,id,id))old)(s,@selector(setValue:forHTTPHeaderField:),v,f);}));}}

    // C 函数 hooks (仅安全项)
    fhk("sysctlbyname",f_sbn,(void**)&o_sbn);
    fhk("uname",f_uname,(void**)&o_uname);

    NSLog(@"[QNByPass] Ultimate loaded");
}
__attribute__((constructor))static void init(void){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{install();});}
