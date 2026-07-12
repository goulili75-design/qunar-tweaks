/*
 * QNByPass - 去哪儿旅行越狱屏蔽 Tweak
 * ======================================
 *
 * 适用环境：Dopamine (rootless) + RootHide
 * 目标App：  com.qunar.iphoneclient (去哪儿旅行)
 * 版本：     v5.3.17+
 *
 * ========== 设计原则 ==========
 * 1. 屏蔽去哪儿官方的越狱检测逻辑
 * 2. 不干扰第三方注入的 bypass dylib：
 *    - ATHelper.dylib (Shadow)
 *    - qninjector.dylib (DSCP/ACTC篡改)
 *    - libsubstrate.dylib (Hook引擎)
 * 3. 让现有 bypass dylib 正常工作
 * 4. 额外覆盖 RootHide 遗漏的检测点
 *
 * ========== 关键风控路径 ==========
 * - qpub_clientRisk (风控请求，加密fp数据)
 * - f_common_actc (设备安全检查)
 * - f_common_adfp (设备指纹)
 * - h_hlist (酒店搜索 → 被风控拦截的目标)
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <objc/runtime.h>
#import <substrate.h>

// ============================================================
// MARK: - 辅助宏
// ============================================================

#define QN_ORIG(cls, sel) MSHookMessageEx

// ============================================================
// MARK: - 1. UIDevice 越狱检测 Hook
// ============================================================

#pragma mark - UIDevice Jailbreak Detection

// 拦截所有 UIDevice 上的越狱检测 category 方法
%hook UIDevice

// 通用的 "isJailbroken" 系列方法
- (BOOL)isJailbroken { return NO; }
- (BOOL)isJailBreak { return NO; }
- (BOOL)isJailBroken { return NO; }
- (BOOL)isJailbreak { return NO; }
- (BOOL)IsJailbreaked { return NO; }
- (BOOL)isDeviceJailbroken { return NO; }
- (BOOL)isJailBrokenDevice { return NO; }
- (BOOL)isJailbrokenDetected { return NO; }
- (BOOL)isJailBrokenDetectedByVOS { return NO; }
- (BOOL)isRootedOrJailbroken { return NO; }
- (BOOL)isDeviceNonCompliant { return NO; }

// 具体的检测方法
- (BOOL)isCydiaJailBreak { return NO; }
- (BOOL)ischeckCydiaJailBreak { return NO; }
- (BOOL)isJailBreak_appList { return NO; }
- (BOOL)isJailBreak_cydia { return NO; }
- (BOOL)isJailBreak_file { return NO; }
- (BOOL)isJailBreak_env { return NO; }
- (BOOL)isJailBreakon { return NO; }
- (BOOL)isPathJailBreak { return NO; }
- (BOOL)isApplicationsJailBreak { return NO; }
- (BOOL)isJailBreakByEnv { return NO; }
- (BOOL)isJailBreakByStat { return NO; }
- (BOOL)checkJailbroken { return NO; }
- (BOOL)computeIsJailbroken { return NO; }
- (BOOL)boolIsjailbreak { return NO; }
- (BOOL)is_jail { return NO; }
- (BOOL)AmIJailbroken_ { return NO; }

// 调试器检测
- (BOOL)isDebuggerCheckDetectedByVOS { return NO; }
- (BOOL)isDFPHookedDetecedByVOS { return NO; }

// 支付相关的越狱检测 (o_pay)
- (BOOL)o_pay_check_touchid_isjailbreak { return NO; }
- (BOOL)o_pay_sdk_isJail { return NO; }

// 通用的 jailbroken 属性获取
- (BOOL)jailbroken { return NO; }
- (BOOL)jailBreak { return NO; }
- (BOOL)jailBrokenJudge { return NO; }
- (NSString *)jailbreakStatus { return @"0"; }

%end


// ============================================================
// MARK: - 2. NSFileManager 文件检测 Hook
// ============================================================

#pragma mark - NSFileManager File Existence Check

// 已知的越狱检测路径 (rootless + 传统)
static NSSet *jailbreakPaths(void) {
    static NSSet *paths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        paths = [[NSSet alloc] initWithArray:@[
            // Rootless 路径 (Dopamine)
            @"/var/jb",
            @"/var/jb/Applications",
            @"/var/jb/bin/bash",
            @"/var/jb/etc/apt",
            @"/var/jb/Library/MobileSubstrate",
            @"/var/jb/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/var/jb/Library/dpkg/info",
            @"/var/jb/usr/libexec/cydia",
            @"/var/jb/usr/sbin/sshd",
            @"/var/jb/usr/bin/ssh",
            @"/var/jb/private/var/lib/apt",
            @"/var/jb/var/lib/dpkg/info",
            @"/var/jb/var/lib/cydia",
            @"/var/jb/Applications/Sileo.app",
            @"/var/jb/Applications/Dopamine.app",
            @"/var/jb/Applications/Zebra.app",
            @"/var/jb/usr/lib/libcycript.dylib",
            @"/var/jb/usr/sbin/frida-server",
            @"/var/jb/usr/bin/cycript",
            @"/var/jb/Library/Shadow",
            
            // 传统路径
            @"/Applications/Cydia.app",
            @"/Applications/Sileo.app",
            @"/Applications/Dopamine.app",
            @"/Applications/Zebra.app",
            @"/Applications/WinterBoard.app",
            @"/Applications/blackra1n.app",
            @"/Applications/IntelliScreen.app",
            @"/Applications/FakeCarrier.app",
            @"/Applications/Snoop-itConfig.app",
            @"/Applications/SBSetttings.app",
            
            @"/bin/bash",
            @"/bin/sh",
            @"/bin.sh",
            @"/usr/sbin/sshd",
            @"/usr/bin/ssh",
            @"/usr/bin/cycript",
            @"/usr/local/bin/cycript",
            @"/usr/sbin/frida-server",
            @"/usr/libexec/cydia",
            @"/usr/libexec/sftp-server",
            @"/usr/libexec/ssh-keysign",
            @"/usr/lib/libcycript.dylib",
            
            @"/etc/apt",
            @"/etc/ssh/sshd_config",
            @"/private/etc/apt",
            @"/private/etc/ssh/sshd_config",
            @"/private/etc/dpkg/origins/debian",
            @"/private/var/lib/apt",
            @"/private/var/lib/cydia",
            @"/private/var/tmp/cydia.log",
            @"/private/var/stash",
            @"/private/var/mobileLibrary/SBSettingsThemes",
            
            @"/var/lib/cydia",
            @"/var/lib/dpkg/info",
            @"/var/lib/undecimus/apt",
            @"/var/log/apt",
            @"/var/tmp/cydia.log",
            
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            @"/Library/dpkg/info",
            @"/Library/Shadow",
            
            @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            @"/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            
            @"/.installed_unc0ver",
            @"/.bootstrapped_electra",
            @"/User/Applications",
            
            // 可写入目录检测
            @"/private",
            @"/jb",
        ]];
    });
    return paths;
}

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (path && [jailbreakPaths() containsObject:path]) {
        return NO;
    }
    // 检查路径是否以越狱路径结尾
    if (path) {
        for (NSString *jp in jailbreakPaths()) {
            if ([path hasPrefix:jp] || [path hasSuffix:jp]) {
                return NO;
            }
        }
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (path && [jailbreakPaths() containsObject:path]) {
        if (isDirectory) *isDirectory = NO;
        return NO;
    }
    return %orig;
}

%end


// ============================================================
// MARK: - 3. UIApplication canOpenURL Hook
// ============================================================

#pragma mark - UIApplication URL Scheme Detection

static NSSet *jailbreakURLSchemes(void) {
    static NSSet *schemes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        schemes = [[NSSet alloc] initWithArray:@[
            @"sileo://",
            @"cydia://",
            @"dopamine://",
            @"zbra://",
            @"zebra://",
            @"undecimus://",
            @"apt-repo://",
            @"xina://",
            @"filza://",
            @"activator://",
            @"jbroot://",
            @"ssh://",
            @"icleaner://",
            @"santander://",
            @"postbox://",
        ]];
    });
    return schemes;
}

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    NSString *urlString = [url absoluteString];
    if (urlString) {
        for (NSString *scheme in jailbreakURLSchemes()) {
            if ([urlString hasPrefix:scheme] || 
                [urlString.lowercaseString hasPrefix:scheme.lowercaseString]) {
                return NO;
            }
        }
    }
    return %orig;
}

%end


// ============================================================
// MARK: - 4. NSProcessInfo 环境变量检测 Hook
// ============================================================

#pragma mark - NSProcessInfo Environment Variables

%hook NSProcessInfo

- (NSDictionary *)environment {
    NSMutableDictionary *env = [[%orig mutableCopy] autorelease];
    // 移除越狱注入相关的环境变量
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_LIBRARY_PATH"];
    return env;
}

- (NSString *)hostName {
    return @"iPhone";
}

%end


// ============================================================
// MARK: - 5. sysctl 内核检测 Hook
// ============================================================

#pragma mark - sysctl / sysctlbyname Hook

// Hook 的 function 指针
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

// 需要拦截的内核参数名
static BOOL shouldBlockSysctlName(const char *name) {
    if (!name) return NO;
    
    static NSSet *blockedNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockedNames = [[NSSet alloc] initWithArray:@[
            @"kern.bootargs",
            @"security.mac.proc_enforce",
            @"security.mac.vnode_enforce",
            @"security.mac.max_proc_enforce",
            @"security.mac.portacl.enforce",
        ]];
    });
    
    return [blockedNames containsObject:@(name)];
}

// --- sysctlbyname Hook ---
static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (shouldBlockSysctlName(name)) {
        if (oldp && oldlenp) {
            // 返回默认的安全值
            memset(oldp, 0, *oldlenp);
        }
        // 模拟调用失败
        errno = ENOENT;
        return -1;
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// --- sysctl Hook ---
static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    // 最常见的是 CTL_KERN + KERN_BOOTTIME 路径
    // 保持默认行为，只拦截特定 mib
    if (namelen >= 4 && name[0] == CTL_KERN) {
        if (name[1] == KERN_BOOTTIME) {
            // 返回虚假的启动时间（使用固定值，看起来像正常设备）
            if (oldp && oldlenp && *oldlenp >= sizeof(struct timeval)) {
                struct timeval tv = {0};
                gettimeofday(&tv, NULL);
                tv.tv_sec -= 86400 * 30; // 30天前启动（看起来正常）
                memcpy(oldp, &tv, sizeof(tv));
                *oldlenp = sizeof(tv);
                return 0;
            }
        }
    }
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}


// ============================================================
// MARK: - 6. NSBundle 注入dylib检测 Hook
// ============================================================

#pragma mark - NSBundle Dylib Detection

/*
 * 注意：ATHelper 也在 Hook NSBundle。
 * 我们只补充 Hook bundleWithPath: 和 objectForInfoDictionaryKey:
 * 确保不跟 ATHelper 的 Shadow Hook 冲突。
 * ATHelper 已经处理了 allBundles/allFrameworks/bundleForClass 等。
 */

// 需要隐藏的越狱 dylib 列表（不含第三方 bypass dylib）
static NSSet *hiddenDylibPrefixes(void) {
    static NSSet *prefixes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefixes = [[NSSet alloc] initWithArray:@[
            @"SubstrateLoader",
            @"SSLKillSwitch",
            @"TweakInject",
            @"CydiaSubstrate",
            @"cynject",
            @"CustomWidgetIcons",
            @"PreferenceLoader",
            @"RocketBootstrap",
            @"WeeLoader",
            @"libhooker",
            @"SubstrateInserter",
            @"SubstrateBootstrap",
            @"ABypass",
            @"FlyJB",
            @"Substitute",
            @"Cephei",
            @"Electra",
            @"AppSyncUnified",
            @"FridaGadget",
            @"frida",
            @"libcycript",
            @"systemhook",
            @"roothidepatch",
            @"libroothide",
            @"roothideinit",
        ]];
    });
    return prefixes;
}

%hook NSBundle

/*
 * 注意：ATHelper 已 Hook 了以下方法，这里用 %orig 会调用 ATHelper 的实现：
 * - allBundles
 * - allFrameworks  
 * - bundleForClass:
 * - bundleWithIdentifier:
 * - initWithPath: (调用 _replaced_bundleWithPath)
 * - initWithURL:
 * - pathForResource:ofType:
 * - URLForResource:withExtension:
 *  
 * 我们只补充 ATHelper 可能未覆盖的方法
 */

// 获取 bundle 的 executable path（App 用此检测 dylib）
- (NSString *)executablePath {
    NSString *path = %orig;
    if (path) {
        NSString *fileName = [[path lastPathComponent] stringByDeletingPathExtension];
        for (NSString *prefix in hiddenDylibPrefixes()) {
            if ([fileName hasPrefix:prefix]) {
                return nil;
            }
        }
    }
    return path;
}

%end


// ============================================================
// MARK: - 7. DTTJailbreakDetection / OneSignalJailbreakDetection Hook
// ============================================================

#pragma mark - Third-party Jailbreak Detection SDK

// DTTJailbreakDetection (Digital Travel Technology)
%hook DTTJailbreakDetection
- (BOOL)isJailbroken { return NO; }
- (BOOL)isDeviceJailbroken { return NO; }
- (BOOL)checkJailbreak { return NO; }
+ (BOOL)isJailbroken { return NO; }
+ (BOOL)isDeviceJailbroken { return NO; }
%end

// OneSignalJailbreakDetection
%hook OneSignalJailbreakDetection
- (BOOL)isJailbroken { return NO; }
+ (BOOL)isJailbroken { return NO; }
%end

// JailbreakDetection (去哪儿自定义类)
%hook JailbreakDetection
- (BOOL)isJailbroken { return NO; }
- (BOOL)isDeviceJailbroken { return NO; }
- (BOOL)boolIsjailbreak { return NO; }
- (BOOL)computeIsJailbroken { return NO; }
- (BOOL)jailBrokenJudge { return NO; }
- (NSString *)jailbreakStatus { return @"0"; }
+ (BOOL)isJailbroken { return NO; }
+ (BOOL)isDeviceJailbroken { return NO; }
%end

// JailbreakDetectionVC
%hook JailbreakDetectionVC
- (BOOL)isJailbroken { return NO; }
- (BOOL)isDeviceJailbroken { return NO; }
%end

// RVPBridgeExtension4Jailbroken
%hook RVPBridgeExtension4Jailbroken
- (BOOL)isJailbroken { return NO; }
+ (BOOL)isJailbroken { return NO; }
%end


// ============================================================
// MARK: - 8. 风控指纹 fp 参数净化 Hook
// ============================================================

#pragma mark - Risk Control Fingerprint (fp) Protection

/*
 * 风控端点: POST slugger.qunar.com/slugger-proxy?qrt=qpub_clientRisk
 * 此请求携带:
 *   - fp header: base64 编码的设备指纹（包含越狱检测结果）
 *   - body: 二进制加密的设备安全数据
 *
 * 由于 qninjector 已经在 Hook NSJSONSerialization 处理 DSCP/ACTC，
 * 这里 Hook NSMutableURLRequest 追加一层防护：
 *   确保 fp header 中不含越狱标记
 */

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // 不过滤，让原始请求通过。qninjector 负责 JSON body，
    // ATHelper 负责系统检测，我们不做网络层拦截。
    %orig;
}

%end


// ============================================================
// MARK: - 9. stat / statfs / access Hook
// ============================================================

#pragma mark - stat / statfs Hook

static int (*orig_stat)(const char *, struct stat *);
static int (*orig_lstat)(const char *, struct stat *);
static int (*orig_statfs)(const char *, struct statfs *);
static int (*orig_access)(const char *, int);

static BOOL isJailbreakFilePath(const char *path) {
    if (!path) return NO;
    NSString *pathStr = @(path);
    // 检查路径是否以越狱目录开头
    if ([pathStr hasPrefix:@"/var/jb"]) return YES;
    if ([pathStr hasPrefix:@"/Library/MobileSubstrate"]) return YES;
    if ([pathStr hasPrefix:@"/Library/dpkg"]) return YES;
    if ([pathStr hasPrefix:@"/Library/Shadow"]) return YES;
    // 检查是否是越狱 App 路径
    if ([pathStr containsString:@"Cydia.app"]) return YES;
    if ([pathStr containsString:@"Sileo.app"]) return YES;
    if ([pathStr containsString:@"Dopamine.app"]) return YES;
    if ([pathStr containsString:@"Zebra.app"]) return YES;
    if ([pathStr containsString:@"frida"]) return YES;
    return NO;
}

static int hooked_stat(const char *path, struct stat *buf) {
    if (isJailbreakFilePath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_stat(path, buf);
}

static int hooked_lstat(const char *path, struct stat *buf) {
    if (isJailbreakFilePath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_lstat(path, buf);
}

static int hooked_access(const char *path, int mode) {
    if (isJailbreakFilePath(path)) {
        errno = EACCES;
        return -1;
    }
    return orig_access(path, mode);
}


// ============================================================
// MARK: - 10. dladdr / _dyld_get_image_name Hook
// ============================================================

#pragma mark - DYLD Hook

/*
 * App 使用 dladdr + _dyld_get_image_name 检测进程加载的 dylib
 * 如果返回越狱 dylib 的路径，App 会标记为越狱
 *
 * 注意：不要拦截 ATHelper / qninjector / libsubstrate 的路径
 */

static BOOL shouldHideImagePath(const char *path) {
    if (!path) return NO;
    NSString *p = @(path);
    // 第三方 bypass dylib - 不拦截
    if ([p containsString:@"ATHelper"]) return NO;
    if ([p containsString:@"qninjector"]) return NO;
    if ([p containsString:@"libsubstrate"]) return NO;
    // 越狱相关 dylib - 需要拦截
    for (NSString *prefix in hiddenDylibPrefixes()) {
        if ([p containsString:prefix]) return YES;
    }
    // 越狱路径 - 需要拦截
    return isJailbreakFilePath(path);
}

static int (*orig_dladdr)(const void *, Dl_info *);
static int hooked_dladdr(const void *addr, Dl_info *info) {
    int ret = orig_dladdr(addr, info);
    if (ret != 0 && info && info->dli_fname) {
        if (shouldHideImagePath(info->dli_fname)) {
            // 替换为系统库路径
            info->dli_fname = "/usr/lib/libSystem.B.dylib";
            info->dli_fbase = NULL;
            info->dli_sname = NULL;
            info->dli_saddr = NULL;
        }
    }
    return ret;
}


// ============================================================
// MARK: - 11. fork / system / popen 沙箱逃逸检测 Hook
// ============================================================

#pragma mark - Sandbox Escape Detection

static pid_t (*orig_fork)(void);
static int (*orig_system)(const char *);
static FILE *(*orig_popen)(const char *, const char *);

static pid_t hooked_fork(void) {
    // fork 在越狱设备上可能成功，非越狱沙箱应该失败
    errno = EPERM;
    return -1;
}

static int hooked_system(const char *cmd) {
    // system() 在沙箱中应不可用
    errno = EPERM;
    return -1;
}

static FILE *hooked_popen(const char *cmd, const char *mode) {
    errno = EPERM;
    return NULL;
}


// ============================================================
// MARK: - %ctor 构造函数
// ============================================================

%ctor {
    @autoreleasepool {
        
        // ---- MSHookFunction for C functions ----
        
        // sysctl
        MSHookFunction(
            (void *)sysctl,
            (void *)hooked_sysctl,
            (void **)&orig_sysctl);
        
        MSHookFunction(
            (void *)sysctlbyname,
            (void *)hooked_sysctlbyname,
            (void **)&orig_sysctlbyname);
        
        // stat/lstat/access
        MSHookFunction(
            (void *)stat,
            (void *)hooked_stat,
            (void **)&orig_stat);
        
        MSHookFunction(
            (void *)lstat,
            (void *)hooked_lstat,
            (void **)&orig_lstat);
        
        MSHookFunction(
            (void *)access,
            (void *)hooked_access,
            (void **)&orig_access);
        
        // dladdr
        MSHookFunction(
            (void *)dladdr,
            (void *)hooked_dladdr,
            (void **)&orig_dladdr);
        
        // fork/system/popen - 沙箱检测
        MSHookFunction(
            (void *)fork,
            (void *)hooked_fork,
            (void **)&orig_fork);
        
        MSHookFunction(
            (void *)system,
            (void *)hooked_system,
            (void **)&orig_system);
        
        MSHookFunction(
            (void *)popen,
            (void *)hooked_popen,
            (void **)&orig_popen);
        
        NSLog(@"[QNByPass] ✅ 去哪儿越狱屏蔽 Tweak 已加载");
        NSLog(@"[QNByPass] 📋 已Hook: UIDevice / NSFileManager / UIApplication / NSProcessInfo / NSBundle");
        NSLog(@"[QNByPass] 📋 已Hook: sysctl / stat / dladdr / fork / system");
        NSLog(@"[QNByPass] 📋 已Hook: DTTJailbreakDetection / OneSignalJailbreakDetection / JailbreakDetection");
        NSLog(@"[QNByPass] ⚠️  保留: ATHelper.dylib / qninjector.dylib / libsubstrate.dylib");
    }
}
