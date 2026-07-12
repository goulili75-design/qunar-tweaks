// ViewController.m - 改机主界面
#import "ViewController.h"
#import <objc/runtime.h>

#define CONFIG_PATH @"/var/jb/var/mobile/Documents/.qnbypass_config.plist"

@implementation ViewController {
    UILabel *statusLabel, *uuidLabel, *deviceLabel;
    UIButton *selectBtn, *actionBtn;
    NSString *selectedBundle;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"QNByPass 改机";
    
    CGFloat y = 100, w = self.view.bounds.size.width - 40;
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 30)];
    title.text = @"去哪儿一键改机"; title.font = [UIFont boldSystemFontOfSize:22];
    title.textAlignment = NSTextAlignmentCenter; [self.view addSubview:title]; y += 50;
    
    // 选择 App
    selectBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    selectBtn.frame = CGRectMake(20, y, w, 44);
    [selectBtn setTitle:@"选择去哪儿 App" forState:UIControlStateNormal];
    [selectBtn addTarget:self action:@selector(selectApp) forControlEvents:UIControlEventTouchUpInside];
    selectBtn.backgroundColor = [UIColor systemBlueColor];
    [selectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    selectBtn.layer.cornerRadius = 10;
    [self.view addSubview:selectBtn]; y += 60;
    
    // 状态
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 40)];
    statusLabel.text = @"状态：未配置"; statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor grayColor]; [self.view addSubview:statusLabel]; y += 50;
    
    // 设备信息
    uuidLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 40)];
    uuidLabel.text = [NSString stringWithFormat:@"伪装IDFV: %@", [self loadConfig][@"idfv"] ?: @"默认"];
    uuidLabel.font = [UIFont systemFontOfSize:12]; uuidLabel.textColor = [UIColor grayColor];
    uuidLabel.textAlignment = NSTextAlignmentCenter; [self.view addSubview:uuidLabel]; y += 30;
    
    deviceLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 40)];
    deviceLabel.text = [NSString stringWithFormat:@"伪装型号: %@", [self loadConfig][@"hwMachine"] ?: @"iPhone14,4"];
    deviceLabel.font = [UIFont systemFontOfSize:12]; deviceLabel.textColor = [UIColor grayColor];
    deviceLabel.textAlignment = NSTextAlignmentCenter; [self.view addSubview:deviceLabel]; y += 50;
    
    // 一键改机按钮
    actionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    actionBtn.frame = CGRectMake(20, y, w, 56);
    [actionBtn setTitle:@"⚡ 一键改机" forState:UIControlStateNormal];
    actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [actionBtn addTarget:self action:@selector(doModify) forControlEvents:UIControlEventTouchUpInside];
    actionBtn.backgroundColor = [UIColor systemGreenColor];
    [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    actionBtn.layer.cornerRadius = 14;
    [self.view addSubview:actionBtn]; y += 80;
    
    // 说明
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w, 100)];
    info.text = @"点击后将：\n① 伪装设备 ID、型号等硬件信息\n② 激活越狱检测屏蔽\n③ 重启去哪儿 App 后生效";
    info.numberOfLines = 0; info.font = [UIFont systemFontOfSize:13];
    info.textColor = [UIColor secondaryLabelColor];
    info.textAlignment = NSTextAlignmentCenter; [self.view addSubview:info];
    
    // 自动选择 Qunar
    selectedBundle = @"com.qunar.iphoneclient";
    [selectBtn setTitle:@"✓ 去哪儿旅行 (已自动选择)" forState:UIControlStateNormal];
    selectBtn.backgroundColor = [UIColor systemGreenColor];
    
    // 刷新状态
    [self refreshStatus];
}

- (NSMutableDictionary *)loadConfig {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:CONFIG_PATH];
    return d ?: [NSMutableDictionary dictionary];
}

- (void)saveConfig:(NSDictionary *)dict {
    [dict writeToFile:CONFIG_PATH atomically:YES];
}

- (void)selectApp {
    // 已自动选择去哪儿
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已选择" 
        message:@"目标 App: 去哪儿旅行 (com.qunar.iphoneclient)" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doModify {
    // 生成随机 IDFV
    NSString *newUUID = [[NSUUID UUID] UUIDString];
    NSString *newDeviceName = @"iPhone";
    
    // 随机设备型号池
    NSArray *models = @[@"iPhone14,4", @"iPhone14,5", @"iPhone14,2", @"iPhone14,3", @"iPhone13,2", @"iPhone13,3"];
    NSString *newModel = models[arc4random_uniform((uint32_t)models.count)];
    
    NSDictionary *config = @{
        @"enabled": @YES,
        @"bundle": selectedBundle ?: @"com.qunar.iphoneclient",
        @"idfv": newUUID,
        @"deviceName": newDeviceName,
        @"model": @"iPhone",
        @"hwMachine": newModel,
        @"updatedAt": [NSDate date]
    };
    
    [self saveConfig:config];
    [self refreshStatus];
    
    // 弹窗提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ 改机完成！"
        message:[NSString stringWithFormat:@"设备信息已伪装：\nIDFV: %@\n型号: %@\n\n越狱屏蔽已激活。\n请重新打开去哪儿 App。", 
                 [newUUID substringToIndex:8], newModel]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        // 杀掉去哪儿让它重启
        system("killall -9 QunariPhone_Cook_CM 2>/dev/null");
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshStatus {
    NSDictionary *cfg = [self loadConfig];
    BOOL enabled = [cfg[@"enabled"] boolValue];
    statusLabel.text = enabled ? @"✅ 状态：已激活（越狱屏蔽+改机）" : @"⚠️ 状态：未激活";
    statusLabel.textColor = enabled ? [UIColor systemGreenColor] : [UIColor orangeColor];
    uuidLabel.text = [NSString stringWithFormat:@"伪装IDFV: %@...", [cfg[@"idfv"] substringToIndex:8] ?: @"默认"];
    deviceLabel.text = [NSString stringWithFormat:@"伪装型号: %@", cfg[@"hwMachine"] ?: @"iPhone14,4"];
    
    if (enabled) {
        actionBtn.backgroundColor = [UIColor systemOrangeColor];
        [actionBtn setTitle:@"🔄 重新改机" forState:UIControlStateNormal];
    }
}
@end
