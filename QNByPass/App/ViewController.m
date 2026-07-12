// ViewController.m - 改机主界面
#import "ViewController.h"
#import <stdlib.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;
#define CONFIG_PATH @"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"

@implementation ViewController {
    UILabel *statusLabel;
    UIButton *modBtn, *clearBtn;
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
    statusLabel.text = @"⚠️ 未激活"; statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor orangeColor]; [self.view addSubview:statusLabel]; y += 50;
    
    clearBtn = [self btn:CGRectMake(20,y,w,48) title:@"🗑 清除去哪儿数据" color:[UIColor systemRedColor] sel:@selector(doClear)];
    [self.view addSubview:clearBtn]; y += 58;
    
    modBtn = [self btn:CGRectMake(20,y,w,48) title:@"⚡ 一键改机" color:[UIColor systemGreenColor] sel:@selector(doModify)];
    [self.view addSubview:modBtn]; y += 65;
    
    [self refreshStatus];
}

- (UIButton *)btn:(CGRect)f title:(NSString *)t color:(UIColor *)c sel:(SEL)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f; [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14]; b.backgroundColor = c;
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10; [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)showAlert:(NSString *)t msg:(NSString *)m {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:t message:m preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)saveConfig:(NSDictionary *)d {
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/jb/var/mobile/Library/Preferences" withIntermediateDirectories:YES attributes:nil error:nil];
    [d writeToFile:CONFIG_PATH atomically:YES];
}
- (NSMutableDictionary *)loadConfig {
    return [NSMutableDictionary dictionaryWithContentsOfFile:CONFIG_PATH] ?: [NSMutableDictionary dictionary];
}
- (void)refreshStatus {
    BOOL en = [[self loadConfig][@"enabled"] boolValue];
    statusLabel.text = en ? @"✅ 已激活" : @"⚠️ 未激活";
    statusLabel.textColor = en ? [UIColor systemGreenColor] : [UIColor orangeColor];
}

- (void)doModify {
    NSArray *mList = @[@"iPhone14,4",@"iPhone14,5",@"iPhone14,2",@"iPhone14,3",@"iPhone13,2",@"iPhone13,3"];
    [self saveConfig:@{@"enabled":@YES, @"hwMachine":mList[arc4random_uniform((uint32_t)mList.count)], @"idfv":[[NSUUID UUID] UUIDString]}];
    [self refreshStatus];
    [self showAlert:@"✅ 改机完成" msg:@"请打开去哪儿测试搜索酒店"];
}

// 后台清除（不卡UI）
- (void)doClear {
    [clearBtn setEnabled:NO];
    [clearBtn setTitle:@"清除中..." forState:UIControlStateNormal];
    
    NSString *script = 
        @"B='com.qunar.iphoneclient'; "
        @"killall -9 QunariPhone_Cook_CM 2>/dev/null; "
        // 主容器
        @"for P in /var/mobile/Containers/Data/Application/*/.com.apple.mobile_container_manager.metadata.plist /var/jb/var/mobile/Containers/Data/Application/*/.com.apple.mobile_container_manager.metadata.plist; do "
        @"  [ -f \"$P\" ] && grep -q \"$B\" \"$P\" 2>/dev/null && rm -rf \"$(dirname \"$P\")\" && echo \"OK\"; "
        @"done; "
        // AppGroup
        @"for P in /var/mobile/Containers/Shared/AppGroup/*/.com.apple.mobile_container_manager.metadata.plist /var/jb/var/mobile/Containers/Shared/AppGroup/*/.com.apple.mobile_container_manager.metadata.plist; do "
        @"  [ -f \"$P\" ] && grep -qi 'qunar' \"$P\" 2>/dev/null && rm -rf \"$(dirname \"$P\")\"; "
        @"done; "
        // Keychain
        @"killall -9 securityd 2>/dev/null; rm -f /var/Keychains/keychain-2.db* /var/jb/var/Keychains/keychain-2.db* 2>/dev/null; "
        // 缓存
        @"rm -rf /var/mobile/Library/Caches/com.apple.LaunchServices* /var/jb/var/mobile/Library/Caches/com.apple.LaunchServices* 2>/dev/null; "
        @"echo DONE";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        setuid(0);
        pid_t pid;
        const char *argv[] = {"/var/jb/bin/sh", "-c", [script UTF8String], NULL};
        int ret = posix_spawn(&pid, "/var/jb/bin/sh", NULL, NULL, (char *const *)argv, environ);
        if (ret == 0) waitpid(pid, NULL, 0);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [clearBtn setEnabled:YES];
            [clearBtn setTitle:@"🗑 清除去哪儿数据" forState:UIControlStateNormal];
            [self showAlert:ret==0?@"✅ 清除完成":@"❌ 清除失败" msg:ret==0?@"请重新打开去哪儿":@"请检查权限或尝试重启手机"];
        });
    });
}
@end
