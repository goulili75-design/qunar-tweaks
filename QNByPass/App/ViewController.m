// ViewController.m - 纯 Dopamine 版
#import "ViewController.h"
#import <stdlib.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;
#define CONFIG @"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"

static void runRoot(NSString *cmd) {
    pid_t p;
    const char *a[] = {"/var/jb/bin/sh", "-c", [cmd UTF8String], NULL};
    if (posix_spawn(&p, "/var/jb/bin/sh", NULL, NULL, (char*const*)a, environ) == 0) waitpid(p, NULL, 0);
}

@implementation ViewController {
    UILabel *statusLabel;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"QNByPass";
    CGFloat y = 80, w = self.view.bounds.size.width - 40;
    
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20,y,w,30)];
    t.text = @"去哪儿改机"; t.font = [UIFont boldSystemFontOfSize:22]; t.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:t]; y += 40;
    
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,y,w,30)];
    statusLabel.text = @"未激活"; statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor orangeColor]; [self.view addSubview:statusLabel]; y += 40;
    
    UIButton *b1 = [self btn:CGRectMake(20,y,w,46) title:@"🗑 清除去哪儿数据" color:[UIColor systemRedColor] sel:@selector(doClear)];
    [self.view addSubview:b1]; y += 55;
    UIButton *b2 = [self btn:CGRectMake(20,y,w,46) title:@"⚡ 一键改机" color:[UIColor systemGreenColor] sel:@selector(doModify)];
    [self.view addSubview:b2]; y += 65;
    
    [self refreshStatus];
}

- (UIButton *)btn:(CGRect)f title:(NSString *)t color:(UIColor *)c sel:(SEL)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f; [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15]; b.backgroundColor = c;
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10; [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)showAlert:(NSString *)t msg:(NSString *)m {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:t message:m preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)saveConfig:(NSDictionary *)d {
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/jb/var/mobile/Library/Preferences" withIntermediateDirectories:YES attributes:nil error:nil];
    [d writeToFile:CONFIG atomically:YES];
}
- (NSMutableDictionary *)loadConfig {
    return [NSMutableDictionary dictionaryWithContentsOfFile:CONFIG] ?: [NSMutableDictionary dictionary];
}
- (void)refreshStatus {
    BOOL en = [[self loadConfig][@"enabled"] boolValue];
    statusLabel.text = en ? @"✅ 已激活" : @"⚠️ 未激活";
    statusLabel.textColor = en ? [UIColor systemGreenColor] : [UIColor orangeColor];
}

- (void)doModify {
    NSArray *ml = @[@"iPhone14,4",@"iPhone14,5",@"iPhone14,2",@"iPhone14,3"];
    NSString *m = ml[arc4random_uniform((uint32_t)ml.count)];
    [self saveConfig:@{@"enabled":@YES, @"hwMachine":m, @"idfv":[[NSUUID UUID] UUIDString]}];
    [self refreshStatus];
    [self showAlert:@"✅ 改机完成" msg:[NSString stringWithFormat:@"伪装型号: %@\n请打开去哪儿测试", m]];
}

- (void)doClear {
    runRoot(@"killall -9 QunariPhone_Cook_CM 2>/dev/null; sleep 1; "
            @"B='com.qunar.iphoneclient'; "
            @"for P in /var/jb/var/mobile/Containers/Data/Application/*/.com.apple.mobile_container_manager.metadata.plist; do "
            @"grep -q \"$B\" \"$P\" 2>/dev/null && rm -rf \"$(dirname \"$P\")\" && echo OK; done; "
            @"for P in /var/jb/var/mobile/Containers/Shared/AppGroup/*/.com.apple.mobile_container_manager.metadata.plist; do "
            @"grep -qi qunar \"$P\" 2>/dev/null && rm -rf \"$(dirname \"$P\")\"; done; "
            @"rm -f /var/jb/var/Keychains/keychain-2.db* 2>/dev/null; "
            @"killall -9 securityd 2>/dev/null; "
            @"uicache -a 2>/dev/null");
    [self showAlert:@"✅ 清除完成" msg:@"数据+登录状态+钥匙串已全部清除\n请重新打开去哪儿"];
}
@end
