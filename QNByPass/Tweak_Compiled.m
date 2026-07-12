// v3: + UIKit + UIDevice hooks
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "substrate.h"

static BOOL hookNo(id _s, SEL _c, ...) { return NO; }

__attribute__((constructor))
static void init(void) {
    NSLog(@"[QNByPass] v3 loading...");
    
    Class c = NSClassFromString(@"UIDevice");
    if (c) {
        SEL sl[] = {
            @selector(isJailbroken),@selector(isJailBreak),@selector(isJailBroken),
            @selector(isDeviceJailbroken),@selector(checkJailbroken)
        };
        for (int i = 0; i < sizeof(sl)/sizeof(SEL); i++) {
            Method m = class_getInstanceMethod(c, sl[i]);
            if (m) class_replaceMethod(c, sl[i], (IMP)hookNo, method_getTypeEncoding(m));
        }
    }
    
    NSLog(@"[QNByPass] v3 loaded OK!");
}
