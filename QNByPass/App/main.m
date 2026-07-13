// main.m
#import <UIKit/UIKit.h>

@interface AppDel : UIResponder <UIApplicationDelegate>
@property UIWindow *window;
@end
@implementation AppDel
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opt {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20,100,300,50)];
    l.text = @"QNByPass OK!"; l.textAlignment = NSTextAlignmentCenter;
    [self.window addSubview:l];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDel class]));
    }
}
