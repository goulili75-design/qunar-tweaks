// ViewController.m - 极简测试版
#import "ViewController.h"
#import <stdlib.h>

#define CONFIG @"/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"

@implementation ViewController {
    UILabel *statusLabel;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"QNByPass";
    CGFloat y = 80, w = self.view.bounds.size.width - 40;
    
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20,y,w,30)];
    t.text = @"去哪儿改机 v3"; t.font = [UIFont boldSystemFontOfSize:22]; t.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:t]; y += 50;
    
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,y,w,60)];
    statusLabel.text = @"点击下方按钮\n（App加载正常）"; statusLabel.numberOfLines = 2;
    statusLabel.textAlignment = NSTextAlignmentCenter; statusLabel.textColor = [UIColor grayColor];
    [self.view addSubview:statusLabel]; y += 70;
    
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(20, y, w, 50);
    [b setTitle:@"✅ 测试按钮" forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:16];
    b.backgroundColor = [UIColor systemGreenColor];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.layer.cornerRadius = 10;
    [b addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b]; y += 60;
    
    [self refreshStatus];
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
- (NSDictionary *)loadConfig {
    return [NSDictionary dictionaryWithContentsOfFile:CONFIG] ?: @{};
}
- (void)refreshStatus {
    BOOL en = [[self loadConfig][@"enabled"] boolValue];
    statusLabel.text = en ? @"✅ 已激活" : @"App 加载正常\n点击测试";
}

- (void)test { [self showAlert:@"✅ 正常" msg:@"App 运行正常！"]; }
@end
