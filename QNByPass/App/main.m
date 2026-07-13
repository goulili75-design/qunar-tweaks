// main.m - 极简入口，无AppDelegate
#import <UIKit/UIKit.h>

@interface V : UIViewController @end
@implementation V
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 50)];
    l.text = @"QNByPass v3.2 - 正常!"; l.font = [UIFont boldSystemFontOfSize:20]; l.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:l];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        w.rootViewController = [[V alloc] init];
        [w makeKeyAndVisible];
        // 保持事件循环
        [[NSRunLoop currentRunLoop] run];
    }
}
