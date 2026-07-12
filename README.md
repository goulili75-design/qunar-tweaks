# Qunar Tweaks

去哪儿旅行（Qunar Travel）越狱屏蔽插件合集，适用于 **Dopamine (rootless) + RootHide** 环境。

## 📦 当前插件

| 插件 | 功能 | 状态 |
|------|------|------|
| **QNByPass** | 越狱检测全面屏蔽（50+ Hook点） | v1.0.0 |

## 🚀 快速安装

### 方法一：从 Actions 下载 deb

1. 点击 [Actions](../../actions) → 选择最新成功的 Workflow
2. 下载 `QNByPass-deb` artifact
3. 解压后用 Sileo/Filza 安装

### 方法二：手动编译

```bash
# 需要 macOS + Theos
git clone https://github.com/goulili75-design/qunar-tweaks.git
cd qunar-tweaks/QNByPass
make package FINALPACKAGE=1
```

## 🛡️ 工作原理

```
QNByPass Tweak
├── UIDevice Hook (30+ jailbreak detection methods)
├── NSFileManager Hook (40+ jailbreak paths → NO)
├── UIApplication Hook (14 jailbreak URL schemes → NO)
├── NSProcessInfo Hook (clears DYLD_INSERT_LIBRARIES)
├── sysctl / stat / dladdr Hook (C function)
├── fork / system / popen Hook (sandbox escape)
└── DTT/OneSignal/JailbreakDetection class Hook
```

## ⚠️ 注意事项

- 仅支持 **Dopamine rootless** 越狱
- 需要 iOS 14.0+
- 需要已注入 ATHelper/qninjector/libsubstrate 的 IPA
- 不会干扰第三方注入的 bypass dylib

## 📄 License

MIT
