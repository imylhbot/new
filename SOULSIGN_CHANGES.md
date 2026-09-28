> 2026-09-28 更新：以下为历史说明；当前交付与构建方式以根目录 README-中文.txt 和 Windows/README.md 为准。

# SoulSign 二开说明

本分支基于 MJorb / Seal，面向 SoulSign 品牌和手动 GitHub Release 工作流进行整理。

## 已处理

- App 显示名、默认 Bundle ID、URL Scheme 与图标切换到 SoulSign。
- 新图标已生成 iPhone AppIcon 尺寸和 1024px marketing icon，并同步到 Windows 配对助手素材。
- 保留原有多 Apple ID 账户仓库与按账号 / Team 续签逻辑。
- 新增运行日志页面：查看、复制、分享、清除。
- 新增自动续签设置：开关与提前 24/48/72 小时阈值；在启动、回到前台、LocalDevVPN 回调后进行 best-effort 检查。
- 删除其余 GitHub Actions，只保留 `SoulSign Manual Release`，且仅支持 `workflow_dispatch` 手动触发。
- 最低系统从 iOS 16.0 下调到 iOS 15.0：主 App、Tunnel、DeviceSupport、测试 Target、xcconfig 与 RustBridge 均统一到 15.0。
- 替换 iOS 16-only SwiftUI API：NavigationStack/NavigationPath、PhotosPicker、ShareLink、presentationDetents、presentationDragIndicator、scrollDismissesKeyboard 等。
- 新增 iOS 15 兼容层（PHPicker + UIActivityViewController）以及 `Scripts/audit-ios15-compat.sh` 构建前检查。
- `SoulSign Manual Release`：手动输入版本后构建 `SoulSign.ipa` 并上传 GitHub Releases，同时附源码 ZIP 与 SHA-256。
- Release 构建自动将当前 GitHub 仓库写入更新检查配置，避免继续指向原上游 Release 仓库。

## 有意保留的内部名称

为降低对原项目签名、Tunnel、Minimuxer 和测试结构的破坏，部分 Swift 类型、目录、Xcode target/scheme 仍使用 `Seal` / `SealTunnel`。安装到设备后的 App 显示名称和构建产物名称均为 SoulSign。

## 构建说明

本容器不是 macOS/Xcode 环境，因此这里只能执行 Swift 语法解析、Shell/YAML/Python 静态检查。真正的 iOS 15 编译请在 GitHub Actions 中手动运行唯一保留的 `SoulSign Manual Release`。
