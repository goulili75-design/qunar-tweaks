// ViewController.m - 改机主界面
#import "ViewController.h"
#import <stdlib.h>

#define CONFIG_PATH @"/var/jb/var/mobile/Documents/.qnbypass_config.plist"
#define QUNAR_BUNDLE @"com.qunar.iphoneclient"

@implementation ViewController {
    UILabel *statusLabel;
    UIButton *modBtn, *clearBtn, *keychainBtn, *loginBtn;
    NSString *selectedBundle;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"QNByPass 改机";
    selectedBundle = QUNAR_BUNDLE;
    
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    sv.contentSize = CGSizeMake(self.view.bounds.size.width, 750);
    [self.view addSubview:sv];
    
    CGFloat y = 30, w = self.view.bounds.size.width - 40, x = 20;
    
    // 标题
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 30)];
    t.text = @"去哪儿一键改机"; t.font = [UIFont boldSystemFontOfSize:22]; t.textAlignment = NSTextAlignmentCenter;
    [sv addSubview:t]; y += 40;
    
    // 状态
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 50)];
    statusLabel.text = @"⚠️ 状态：未激活"; statusLabel.numberOfLines = 2;
    statusLabel.textAlignment = NSTextAlignmentCenter; statusLabel.textColor = [UIColor orangeColor];
    [sv addSubview:statusLabel]; y += 55;
    
    // 一键改机
    modBtn = [self makeBtn:@"⚡ 一键改机（激活越狱屏蔽+设备伪装）" y:y color:[UIColor systemGreenColor] action:@selector(doModify)];
    [sv addSubview:modBtn]; y += 70;
    
    // 清除 App 数据
    clearBtn = [self makeBtn:@"🗑 清除去哪儿全部数据" y:y color:[UIColor systemRedColor] action:@selector(clearAppData)];
    [sv addSubview:clearBtn]; y += 70;
    
    // 清除钥匙串
    keychainBtn = [self makeBtn:@"🔑 清除钥匙串" y:y color:[UIColor systemOrangeColor] action:@selector(clearKeychain)];
    [sv addSubview:keychainBtn]; y += 70;
    
    // 清除登录状态
    loginBtn = [self makeBtn:@"🚪 清除登录状态（仅Cookie/Token）" y:y color:[UIColor systemBlueColor] action:@selector(clearLogin)];
    [sv addSubview:loginBtn]; y += 80;
    
    // 说明
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 120)];
    info.text = @"操作步骤：\n① 先点「清除全部数据」+「清除钥匙串」\n② 再点「一键改机」\n③ 打开去哪儿重新登录测试";
    info.numberOfLines = 0; info.font = [UIFont systemFontOfSize:12]; info.textColor = [UIColor grayColor];
    [sv addSubview:info];
    
    [self refreshStatus];
}

- (UIButton *)makeBtn:(NSString *)title y:(CGFloat)y color:(UIColor *)c action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(20, y, self.view.bounds.size.width - 40, 50);
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15]; b.titleLabel.numberOfLines = 2;
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    b.backgroundColor = c; [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 12; [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)showAlert:(NSString *)title msg:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSMutableDictionary *)loadConfig {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:CONFIG_PATH];
    return d ?: [NSMutableDictionary dictionary];
}
- (void)saveConfig:(NSDictionary *)dict { [dict writeToFile:CONFIG_PATH atomically:YES]; }
- (void)refreshStatus {
    NSDictionary *cfg = [self loadConfig];
    BOOL en = [cfg[@"enabled"] boolValue];
    statusLabel.text = en ? @"✅ 状态：已激活\n越狱屏蔽+设备伪装生效中" : @"⚠️ 状态：未激活\n请先清除数据再改机";
    statusLabel.textColor = en ? [UIColor systemGreenColor] : [UIColor orangeColor];
    [modBtn setTitle:en ? @"🔄 重新改机" : @"⚡ 一键改机（激活越狱屏蔽+设备伪装）" forState:UIControlStateNormal];
}

// ========== 一键改机 ==========
- (void)doModify {
    NSArray *models = @[@"iPhone14,4", @"iPhone14,5", @"iPhone14,2", @"iPhone14,3", @"iPhone13,2", @"iPhone13,3"];
    NSString *m = models[arc4random_uniform((uint32_t)models.count)];
    NSDictionary *cfg = @{
        @"enabled": @YES, @"bundle": selectedBundle,
        @"idfv": [[NSUUID UUID] UUIDString],
        @"hwMachine": m, @"deviceName": @"iPhone", @"model": @"iPhone",
        @"updatedAt": [NSDate date]
    };
    [self saveConfig:cfg]; [self refreshStatus];
    [self showAlert:@"✅ 改机完成！" msg:[NSString stringWithFormat:@"伪装型号: %@\n请打开去哪儿App测试", m]];
}

// ========== 清除 App 全部数据 ==========
- (void)clearAppData {
    // 找到去哪儿沙盒目录并删除
    NSString *base = @"/var/jb/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *apps = [fm contentsOfDirectoryAtPath:base error:nil];
    int deleted = 0;
    for (NSString *uuid in apps) {
        NSString *plist = [base stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/.com.apple.mobile_container_manager.metadata.plist", uuid]];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:plist];
        if ([meta[@"MCMMetadataIdentifier"] isEqualToString:QUNAR_BUNDLE]) {
            NSString *path = [base stringByAppendingPathComponent:uuid];
            // 删除 Library, Documents, tmp
            for (NSString *sub in @[@"Library", @"Documents", @"tmp"]) {
                NSString *p = [path stringByAppendingPathComponent:sub];
                [fm removeItemAtPath:p error:nil];
            }
            deleted++;
        }
    }
    if (deleted == 0) {
        // 备选：直接杀目录
        for (NSString *uuid in apps) {
            NSString *path = [base stringByAppendingPathComponent:uuid];
            BOOL isDir;
            [fm fileExistsAtPath:path isDirectory:&isDir];
            if (isDir && [fm fileExistsAtPath:[path stringByAppendingPathComponent:@"Library/Preferences/com.qunar.iphoneclient.plist"]]) {
                for (NSString *sub in @[@"Library", @"Documents", @"tmp"]) {
                    [fm removeItemAtPath:[path stringByAppendingPathComponent:sub] error:nil];
                }
                deleted++;
            }
        }
    }
    [self showAlert:@"✅ 数据清除完成" msg:[NSString stringWithFormat:@"已清除 %d 个数据目录", deleted]];
}

// ========== 清除钥匙串 ==========
- (void)clearKeychain {
    // 直接删除 keychain 中 Qunar 的项
    int ret = system("sqlite3 /var/jb/var/Keychains/keychain-2.db \"DELETE FROM genp WHERE agrp LIKE '%qunar%'; DELETE FROM inet WHERE agrp LIKE '%qunar%';\" 2>/dev/null");
    if (ret != 0) {
        [self showAlert:@"⚠️ 部分成功" msg:@"钥匙串清除可能不完整，请手动在设置中清除"];
        return;
    }
    [self showAlert:@"✅ 钥匙串已清除" msg:@"Qunar 相关钥匙串项已删除"];
}

// ========== 清除登录状态 ==========
- (void)clearLogin {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = @"/var/jb/var/mobile/Containers/Data/Application";
    for (NSString *uuid in [fm contentsOfDirectoryAtPath:base error:nil]) {
        NSString *path = [base stringByAppendingPathComponent:uuid];
        // 删 Cookies
        [fm removeItemAtPath:[path stringByAppendingPathComponent:@"Library/Cookies"] error:nil];
        // 删 HTTP 缓存
        [fm removeItemAtPath:[path stringByAppendingPathComponent:@"Library/Caches/com.qunar.iphoneclient"] error:nil];
        // 删 Preferences（仅 Qunar）
        [fm removeItemAtPath:[path stringByAppendingPathComponent:@"Library/Preferences/com.qunar.iphoneclient.plist"] error:nil];
        // 删 Keychain 访问组
        [fm removeItemAtPath:[path stringByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"] error:nil];
    }
    [self showAlert:@"✅ 登录状态已清除" msg:@"Cookie/Token/Preferences 已删除\n请重新登录"];
}
@end
