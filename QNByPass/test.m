// Simple dylib build test
#import <Foundation/Foundation.h>

__attribute__((constructor))
static void testInit(void) {
    NSLog(@"QNByPass loaded!");
}
