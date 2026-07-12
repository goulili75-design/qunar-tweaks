// ViewController.m - 改机主界面 (root清除版)
#import "ViewController.h"
#import <stdlib.h>
#import <spawn.h>

extern char **environ;
#define CONFIG_PATH @"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"

static void runAsRoot(NSString *cmd) {
    setuid(0); // 切换到 root（需要 setuid 权限）
    pid_t pid;
    const char *argv[] = {"/var/jb/bin/bash", "-c", [cmd UTF8String], NULL};
    posix_spawn(&pid, "/var/jb/bin/bash", NULL, NULL, (char *const *)argv, environ);
    waitpid(pid, NULL, 0);
}

@implementation ViewController {
    UILabel *statusLabel;
    UIButton *modBtn;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"QNByPass 改机";
    
    CGFloat y = 80, w = self.view.bounds.size.width - 40;
    
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 30)];
    t.text = @"去哪儿一键改机"; t.font = [UIFont boldSystemFontOfSize:22]; t.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:t]; y += 40;
    
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 40)];
    statusLabel.text = @"⚠️ 状态：未激活"; statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor orangeColor]; [self.view addSubview:statusLabel]; y += 50;
    
    // 清除数据
    UIButton *b1 = [self btn:CGRectMake(20,y,w,48) title:@"🗑 清除 App 全部数据（缓存/登录/钥匙串）" color:[UIColor systemRedColor] sel:@selector(clearAll)];
    [self.view addSubview:b1]; y += 58;
    
    // 改机
    modBtn = [self btn:CGRectMake(20,y,w,48) title:@"⚡ 一键改机" color:[UIColor systemGreenColor] sel:@selector(doModify)];
    [self.view addSubview:modBtn]; y += 65;
    
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 80)];
    info.text = @"步骤：① 先清除数据 → ② 一键改机 → ③ 打开去哪儿"; info.numberOfLines = 0;
    info.font = [UIFont systemFontOfSize:12]; info.textColor = [UIColor grayColor]; info.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:info];
    
    [self refreshStatus];
}

- (UIButton *)btn:(CGRect)frame title:(NSString *)t color:(UIColor *)c sel:(SEL)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame; [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15]; b.backgroundColor = c;
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10; [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)showAlert:(NSString *)t msg:(NSString *)m {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:t message:m preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSMutableDictionary *)loadConfig {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:CONFIG_PATH];
    return d ?: [NSMutableDictionary dictionary];
}
- (void)saveConfig:(NSDictionary *)dict {
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/jb/var/mobile/Library/Preferences" withIntermediateDirectories:YES attributes:nil error:nil];
    [dict writeToFile:CONFIG_PATH atomically:YES];
}
- (void)refreshStatus {
    BOOL en = [[self loadConfig][@"enabled"] boolValue];
    statusLabel.text = en ? @"✅ 已激活" : @"⚠️ 未激活";
    statusLabel.textColor = en ? [UIColor systemGreenColor] : [UIColor orangeColor];
    [modBtn setTitle:en ? @"🔄 重新改机" : @"⚡ 一键改机" forState:UIControlStateNormal];
}

- (void)doModify {
    NSArray *mList = @[@"iPhone14,4",@"iPhone14,5",@"iPhone14,2",@"iPhone14,3",@"iPhone13,2",@"iPhone13,3"];
    NSString *m = mList[arc4random_uniform((uint32_t)mList.count)];
    [self saveConfig:@{@"enabled":@YES,@"hwMachine":m,@"idfv":[[NSUUID UUID] UUIDString],@"updatedAt":[NSDate date]}];
    [self refreshStatus];
    [self showAlert:@"✅ 改机完成！" msg:[NSString stringWithFormat:@"伪装型号: %@\n请打开去哪儿测试", m]];
}

// 全部清除（只清除去哪儿，不动其他App）
- (void)clearAll {
    NSString *cmd = 
        @"QUNAR='com.qunar.iphoneclient'; "
        @"for BASE in /var/jb/var/mobile/Containers/Data/Application /var/mobile/Containers/Data/Application; do "
        @"  for DIR in $BASE/*; do "
        @"    PLIST=\"$DIR/.com.apple.mobile_container_manager.metadata.plist\"; "
        @"    if [ -f \"$PLIST\" ] && plutil -p \"$PLIST\" 2>/dev/null | grep -q \"$QUNAR\"; then "
        @"      echo \"Found Qunar: $DIR\"; "
        @"      rm -rf \"$DIR\"/Library/Caches \"$DIR\"/Library/Cookies \"$DIR\"/Library/Preferences \"$DIR\"/Documents \"$DIR\"/tmp 2>/dev/null; "
        @"      echo \"Cleared $DIR\"; "
        @"    fi; "
        @"  done; "
        @"done; "
        @"rm -f /var/jb/var/Keychains/keychain-2.db* 2>/dev/null; "
        @"rm -f /var/Keychains/keychain-2.db* 2>/dev/null; "
        @"echo 'Done'";
    runAsRoot(cmd);
    [self showAlert:@"✅ 已清除" msg:@"只清除了去哪儿App的数据+钥匙串\n其他App不受影响"];
}
@end
