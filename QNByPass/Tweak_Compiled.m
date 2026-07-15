// QNByPass v0 - 零Hook基准测试
#import <Foundation/Foundation.h>
__attribute__((constructor))
static void init(void) {
    NSLog(@"[QNByPass] v0 loaded - PID=%d", [[NSProcessInfo processInfo] processIdentifier]);
    // 写文件确认加载
    [[NSString stringWithFormat:@"v0 loaded PID=%d\n", [[NSProcessInfo processInfo] processIdentifier]]
     writeToFile:@"/var/jb/var/mobile/Documents/.qn_loaded.txt" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}
