// Step 1: just initWith the basic
#import <Foundation/Foundation.h>
#import "substrate.h"

__attribute__((constructor))
static void init(void) {
    NSLog(@"[QNByPass] v2 - testing...");
}
