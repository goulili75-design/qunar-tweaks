// libasset_loader - 两阶段加载：Foundation 立即 + UIKit 延迟
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>

static inline void swz(Class c, SEL s, id b) { Method m=class_getInstanceMethod(c,s); if(m) method_setImplementation(m,imp_implementationWithBlock(b)); }
static NSString *rUUID(void) { return [[NSUUID UUID] UUIDString]; }
static NSString *rStr(NSArray *a) { return a[arc4random_uniform((uint32_t)a.count)]; }
static CGFloat rFlt(CGFloat lo, CGFloat hi) { return lo+(CGFloat)arc4random_uniform((uint32_t)((hi-lo)*1000))/1000.0f; }
static BOOL isJBP(const char *p) { return p&&(strstr(p,"/var/jb")||strstr(p,"Cydia")||strstr(p,"Sileo")||strstr(p,"Dopamine")); }

// Phase 1: Foundation hooks (constructor 立即执行，比 Qunar 检测早)
static void p1(void) {
    Class c;
    // NSProcessInfo
    c=NSClassFromString(@"NSProcessInfo");
    swz(c,@selector(hostName),^NSString*(id s){return @"iPhone";});
    swz(c,@selector(physicalMemory),^unsigned long long(id s){return 4000000000ULL;});
    swz(c,@selector(processorCount),^NSUInteger(id s){return 6;});
    // NSFileManager
    c=NSClassFromString(@"NSFileManager");
    Method mf=class_getInstanceMethod(c,@selector(fileExistsAtPath:));
    if(mf){IMP old=method_getImplementation(mf);method_setImplementation(mf,imp_implementationWithBlock(^BOOL(id s,NSString*p){return isJBP([p UTF8String])?NO:((BOOL(*)(id,SEL,id))old)(s,@selector(fileExistsAtPath:),p);}));}
    // NSJSONSerialization
    c=NSClassFromString(@"NSJSONSerialization");
    Method mj=class_getClassMethod(c,@selector(dataWithJSONObject:options:error:));
    IMP oldIMP=method_getImplementation(mj);
    NSData*(*orig)(id,SEL,id,NSJSONWritingOptions,NSError**)=(void*)oldIMP;
    method_setImplementation(mj,imp_implementationWithBlock(^NSData*(id s,id o,NSJSONWritingOptions opt,NSError**e){
        if([o isKindOfClass:[NSDictionary class]]){NSMutableDictionary*d=[(NSDictionary*)o mutableCopy];d[@"encrypted"]=@"Y";return orig(s,@selector(dataWithJSONObject:options:error:),d,opt,e);}
        return orig(s,@selector(dataWithJSONObject:options:error:),o,opt,e);
    }));
    // NSLocale
    swz(NSClassFromString(@"NSLocale"),@selector(localeIdentifier),^NSString*(id s){return rStr(@[@"zh_CN",@"en_US"]);});
    // NSTimeZone
    swz(NSClassFromString(@"NSTimeZone"),@selector(name),^NSString*(id s){return rStr(@[@"Asia/Shanghai",@"Asia/Hong_Kong"]);});
    // NSBundle
    swz(NSClassFromString(@"NSBundle"),@selector(bundleIdentifier),^NSString*(id s){return @"com.qunar.iphoneclient";});
    // NSHTTPCookieStorage
    swz(NSClassFromString(@"NSHTTPCookieStorage"),@selector(cookiesForURL:),^NSArray*(id s,NSURL*u){return @[];});
}

// Phase 2: UIKit hooks (main queue dispatch, UIKit 已就绪)
static void p2(void) {
    Class c=NSClassFromString(@"UIDevice");if(!c)return;
    swz(c,@selector(identifierForVendor),^NSUUID*(id s){return[[NSUUID alloc]initWithUUIDString:rUUID()];});
    swz(c,@selector(name),^NSString*(id s){return @"iPhone";});
    swz(c,@selector(model),^NSString*(id s){return @"iPhone";});
    swz(c,@selector(systemVersion),^NSString*(id s){return rStr(@[@"16.0.2",@"16.0.3",@"16.1",@"16.1.1",@"16.2",@"16.3",@"16.3.1",@"16.4",@"16.4.1",@"16.5",@"16.5.1",@"16.6"]);});
    swz(c,@selector(systemName),^NSString*(id s){return @"iOS";});
    swz(c,@selector(localizedModel),^NSString*(id s){return @"iPhone";});
    swz(NSClassFromString(@"UIScreen"),@selector(brightness),^CGFloat(id s){return rFlt(0.3f,0.8f);});
    swz(NSClassFromString(@"UIScreen"),@selector(bounds),^CGRect(id s){return CGRectMake(0,0,390,844);});
    swz(NSClassFromString(@"ASIdentifierManager"),@selector(advertisingIdentifier),^NSUUID*(id s){return[[NSUUID alloc]initWithUUIDString:rUUID()];});
    swz(NSClassFromString(@"CTTelephonyNetworkInfo"),@selector(subscriberCellularProvider),^id(id s){return nil;});
    swz(NSClassFromString(@"NEVPNManager"),@selector(connection),^id(id s){return nil;});
}

__attribute__((constructor))
static void init(void) {
    p1();  // Foundation: 立即，dyld 阶段，比 Qunar 检测早
    dispatch_async(dispatch_get_main_queue(), ^{ p2(); });  // UIKit: 主队列延迟
}
