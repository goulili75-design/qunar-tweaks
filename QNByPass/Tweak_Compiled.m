// QNByPass 无越狱版 - 只改设备参数
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 延迟 Hook 避免初始化崩溃
static void installHooks(void) {
    Class uid = NSClassFromString(@"UIDevice");
    if (!uid) return;
    
    // IDFV 伪装
    Method m = class_getInstanceMethod(uid, @selector(identifierForVendor));
    if (m) {
        IMP fake = imp_implementationWithBlock(^NSUUID *(id _s) {
            return [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
        });
        method_setImplementation(m, fake);
    }
    // 设备名
    m = class_getInstanceMethod(uid, @selector(name));
    if (m) method_setImplementation(m, imp_implementationWithBlock(^NSString *(id _s) { return @"iPhone"; }));
    // 设备型号
    m = class_getInstanceMethod(uid, @selector(model));
    if (m) method_setImplementation(m, imp_implementationWithBlock(^NSString *(id _s) { return @"iPhone"; }));
    // 系统版本
    m = class_getInstanceMethod(uid, @selector(systemVersion));
    if (m) method_setImplementation(m, imp_implementationWithBlock(^NSString *(id _s) { return @"16.0.3"; }));
    
    // 环境变量清理
    Class pi = NSClassFromString(@"NSProcessInfo");
    if (pi) {
        m = class_getInstanceMethod(pi, @selector(environment));
        if (m) {
            IMP orig = method_getImplementation(m);
            IMP fake = imp_implementationWithBlock(^NSDictionary *(id _s) {
                NSMutableDictionary *env = [((NSDictionary *(*)(id,SEL))orig)(_s, @selector(environment)) mutableCopy];
                [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
                [env removeObjectForKey:@"DYLD_LIBRARY_PATH"];
                return env;
            });
            method_setImplementation(m, fake);
        }
    }
    
    NSLog(@"[QNByPass] Device spoof active");
}

__attribute__((constructor))
static void init(void) {
    // 延迟 2 秒等 App 完成初始化
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{ installHooks(); });
}
