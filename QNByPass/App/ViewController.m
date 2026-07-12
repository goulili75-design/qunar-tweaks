// ViewController.m - 改机主界面
#import "ViewController.h"
#import <stdlib.h>

#define CONFIG_PATH @"/var/jb/var/mobile/Documents/.qnbypass_config.plist"

@implementation ViewController {
    UILabel *statusLabel;
    UIButton *actionBtn;
    NSString *selectedBundle;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"QNByPass";
    
    CGFloat y = 80, w = self.view.bounds.size.width - 40;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 36)];
    title.text = @"去哪儿一键改机"; title.font = [UIFont boldSystemFontOfSize:24];
    title.textAlignment = NSTextAlignmentCenter; [self.view addSubview:title]; y += 50;

    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 80)];
    statusLabel.text = @"选择App后点击按钮即可激活\n越狱屏蔽 + 设备信息伪装";
    statusLabel.numberOfLines = 0; statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor grayColor]; [self.view addSubview:statusLabel]; y += 80;
    
    actionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    actionBtn.frame = CGRectMake(20, y, w, 56);
    [actionBtn setTitle:@"⚡ 一键改机" forState:UIControlStateNormal];
    actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [actionBtn addTarget:self action:@selector(doModify) forControlEvents:UIControlEventTouchUpInside];
    actionBtn.backgroundColor = [UIColor systemGreenColor];
    [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    actionBtn.layer.cornerRadius = 14;
    [self.view addSubview:actionBtn]; y += 80;
    
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 100)];
    info.text = @"点击后将激活：\n① 越狱检测屏蔽\n② 设备信息伪装\n③ 自动重启去哪儿App";
    info.numberOfLines = 0; info.font = [UIFont systemFontOfSize:13];
    info.textColor = [UIColor grayColor]; info.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:info];

    selectedBundle = @"com.qunar.iphoneclient";
    [self refreshStatus];
}

- (NSMutableDictionary *)loadConfig {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:CONFIG_PATH];
    return d ?: [NSMutableDictionary dictionary];
}

- (void)saveConfig:(NSDictionary *)dict {
    [dict writeToFile:CONFIG_PATH atomically:YES];
}

- (void)doModify {
    NSString *newUUID = [[NSUUID UUID] UUIDString];
    NSArray *models = @[@"iPhone14,4", @"iPhone14,5", @"iPhone14,2", @"iPhone14,3"];
    NSString *newModel = models[arc4random_uniform((uint32_t)models.count)];
    
    NSDictionary *config = @{
        @"enabled": @YES,
        @"bundle": selectedBundle ?: @"com.qunar.iphoneclient",
        @"idfv": newUUID,
        @"deviceName": @"iPhone",
        @"model": @"iPhone",
        @"hwMachine": newModel,
        @"updatedAt": [NSDate date]
    };
    
    [self saveConfig:config];
    [self refreshStatus];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ 改机完成！"
        message:[NSString stringWithFormat:@"设备信息已伪装\n型号: %@\n\n请重新打开去哪儿App测试", newModel]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshStatus {
    NSDictionary *cfg = [self loadConfig];
    BOOL enabled = [cfg[@"enabled"] boolValue];
    statusLabel.text = enabled ? @"✅ 状态：已激活" : @"⚠️ 状态：未激活";
    statusLabel.textColor = enabled ? [UIColor systemGreenColor] : [UIColor orangeColor];
    [actionBtn setTitle:enabled ? @"🔄 重新改机" : @"⚡ 一键改机" forState:UIControlStateNormal];
}
@end
