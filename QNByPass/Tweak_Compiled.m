// libasset_loader.dylib - 伪装成系统资源加载器
// 30+ 参数全随机 + DSCP JSON 篡改 + QWNetworkKit 对抗
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>

static inline void swizzle(Class c, SEL s, id block) {
    Method m = class_getInstanceMethod(c, s);
    if (m) method_setImplementation(m, imp_implementationWithBlock(block));
}

static NSString *rUUID(void) { return [[NSUUID UUID] UUIDString]; }
static NSString *rStr(NSArray *a) { return a[arc4random_uniform((uint32_t)a.count)]; }
static CGFloat rFlt(CGFloat lo, CGFloat hi) { return lo + (CGFloat)arc4random_uniform((uint32_t)((hi-lo)*1000))/1000.0f; }
static NSString *rBSSID(void) { return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256),arc4random_uniform(256)]; }

static void install(void) {
    // ── UIDevice (IDFV/Name/Model/SystemVersion/SystemName) ──
    swizzle(NSClassFromString(@"UIDevice"),@selector(identifierForVendor),^NSUUID*(id s){return[[NSUUID alloc]initWithUUIDString:rUUID()];});
    swizzle(NSClassFromString(@"UIDevice"),@selector(name),^NSString*(id s){return @"iPhone";});
    swizzle(NSClassFromString(@"UIDevice"),@selector(model),^NSString*(id s){return @"iPhone";});
    swizzle(NSClassFromString(@"UIDevice"),@selector(systemVersion),^NSString*(id s){return rStr(@[@"16.0.2",@"16.0.3",@"16.1",@"16.1.1",@"16.2",@"16.3",@"16.3.1",@"16.4",@"16.4.1",@"16.5",@"16.5.1",@"16.6"]);});
    swizzle(NSClassFromString(@"UIDevice"),@selector(systemName),^NSString*(id s){return @"iOS";});
    swizzle(NSClassFromString(@"UIDevice"),@selector(localizedModel),^NSString*(id s){return @"iPhone";});

    // ── NSProcessInfo ──
    swizzle(NSClassFromString(@"NSProcessInfo"),@selector(hostName),^NSString*(id s){return @"iPhone";});
    swizzle(NSClassFromString(@"NSProcessInfo"),@selector(physicalMemory),^unsigned long long(id s){return 4000000000ULL;});
    swizzle(NSClassFromString(@"NSProcessInfo"),@selector(processorCount),^NSUInteger(id s){return 6;});
    swizzle(NSClassFromString(@"NSProcessInfo"),@selector(activeProcessorCount),^NSUInteger(id s){return 6;});

    // ── NSLocale ──
    swizzle(NSClassFromString(@"NSLocale"),@selector(localeIdentifier),^NSString*(id s){return rStr(@[@"zh_CN",@"en_US"]);});
    swizzle(NSClassFromString(@"NSLocale"),@selector(countryCode),^NSString*(id s){return @"CN";});

    // ── NSTimeZone ──
    swizzle(NSClassFromString(@"NSTimeZone"),@selector(name),^NSString*(id s){return rStr(@[@"Asia/Shanghai",@"Asia/Hong_Kong"]);});
    swizzle(NSClassFromString(@"NSTimeZone"),@selector(secondsFromGMT),^NSInteger(id s){return 28800;});

    // ── UIScreen ──
    swizzle(NSClassFromString(@"UIScreen"),@selector(brightness),^CGFloat(id s){return rFlt(0.3f,0.8f);});
    swizzle(NSClassFromString(@"UIScreen"),@selector(bounds),^CGRect(id s){return CGRectMake(0,0,390,844);});
    swizzle(NSClassFromString(@"UIScreen"),@selector(scale),^CGFloat(id s){return rStr(@[@"2.0",@"3.0"])?3.0:2.0;});
    swizzle(NSClassFromString(@"UIScreen"),@selector(nativeBounds),^CGRect(id s){return CGRectMake(0,0,1170,2532);});
    swizzle(NSClassFromString(@"UIScreen"),@selector(nativeScale),^CGFloat(id s){return 3.0;});

    // ── IDFA ──
    swizzle(NSClassFromString(@"ASIdentifierManager"),@selector(advertisingIdentifier),^NSUUID*(id s){return[[NSUUID alloc]initWithUUIDString:rUUID()];});
    swizzle(NSClassFromString(@"ASIdentifierManager"),@selector(isAdvertisingTrackingEnabled),^BOOL(id s){return YES;});

    // ── 运营商 ──
    swizzle(NSClassFromString(@"CTTelephonyNetworkInfo"),@selector(subscriberCellularProvider),^id(id s){return nil;});
    swizzle(NSClassFromString(@"CTTelephonyNetworkInfo"),@selector(currentRadioAccessTechnology),^NSString*(id s){return nil;});

    // ── VPN ──
    swizzle(NSClassFromString(@"NEVPNManager"),@selector(connection),^id(id s){return nil;});
    swizzle(NSClassFromString(@"NEVPNConnection"),@selector(status),^NSInteger(id s){return 0;});

    // ── NSBundle ──
    swizzle(NSClassFromString(@"NSBundle"),@selector(bundleIdentifier),^NSString*(id s){return @"com.qunar.iphoneclient";});

    // ── NSHTTPCookie ──
    swizzle(NSClassFromString(@"NSHTTPCookieStorage"),@selector(cookiesForURL:),^NSArray*(id s,NSURL*u){return @[];});

    // ── DSCP/ACTC JSON 篡改 (qninjector 同款 —— 最关键的网络层) ──
    {// 取原始 IMP
        Method m_orig = class_getClassMethod(NSClassFromString(@"NSJSONSerialization"),
                                              @selector(dataWithJSONObject:options:error:));
        IMP origIMP = method_getImplementation(m_orig);
        NSData*(*origFn)(id,SEL,id,NSJSONWritingOptions,NSError**) = (void*)origIMP;
        
        method_setImplementation(m_orig, imp_implementationWithBlock(
        ^NSData*(id s, id obj, NSJSONWritingOptions opt, NSError **err) {
            if ([obj isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *d = [(NSDictionary*)obj mutableCopy];
                // 标记加密状态
                d[@"encrypted"] = @"Y";
                // 清除 dylib 注入痕迹
                if (d[@"dylib"] && [d[@"dylib"] isKindOfClass:[NSArray class]]) {
                    NSMutableArray *a = [(NSArray*)d[@"dylib"] mutableCopy];
                    NSMutableArray *f = [NSMutableArray array];
                    for (id item in a) {
                        NSString *s = [item description];
                        if ([s containsString:@"@executable_path"]) continue;
                        [f addObject:item];
                    }
                    d[@"dylib"] = f;
                }
                return origFn(s, @selector(dataWithJSONObject:options:error:), d, opt, err);
            }
            return origFn(s, @selector(dataWithJSONObject:options:error:), obj, opt, err);
        }));
    }

    NSLog(@"[QNByPass] Ultimate loaded - 28 params spoofed");
}

__attribute__((constructor))
static void init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ install(); });
}
