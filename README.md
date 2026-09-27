# SoulSign

SoulSign 是基于 MJorb / Seal 二次开发的 iOS IPA 本机签名、安装与续签工具，最低支持 iOS 15。

> 开源许可证仍遵循原项目的 GNU AGPL-3.0。第三方组件许可见 `Seal/Resources/ThirdPartyNotices.txt`。

## 本次二开内容

- 应用显示名称改为 **SoulSign**
- Bundle ID 默认改为 `com.mjorb.soulsign`
- 使用 SoulSign 新图标作为 iOS AppIcon，并同步到配对助手图标源
- 保留并增强多 Apple ID 管理，每个应用继续绑定原签名账号 / Team 进行续签
- 支持单应用“立即续签”和“续签全部”
- 新增“自动续签”开关，可选择提前 24 / 48 / 72 小时触发
- 自动续签会在 SoulSign 启动、回到前台或本地连接恢复时检查即将到期的应用
- 新增“运行日志”页面，可查看、复制、分享和清空日志；敏感字段继续经过脱敏处理
- GitHub Actions **只保留一个** `SoulSign Manual Release` 工作流
- 该工作流只有 `workflow_dispatch`，不会因 push / pull request / tag 自动打包
- 手动执行后会编译 iOS 15.0 deployment target、生成 `SoulSign.ipa`，并自动上传到 GitHub Releases

## 自动续签说明

由于 iOS 对普通应用的后台执行时间有严格限制，SoulSign 不承诺在应用完全退出后按固定时间后台运行。当前实现采用更稳定的方式：

1. SoulSign 启动时检查；
2. App 从后台回到前台时检查；
3. LocalDevVPN 回调 / 本地连接恢复后检查；
4. 只有进入用户设置的续签阈值（24 / 48 / 72 小时）才加入自动续签队列；
5. 自动续签仍使用该 App 原来绑定的 Apple ID / Team，避免 Team 改变导致覆盖安装或 Keychain 异常。

自动续签需要有效 Apple ID 会话、可用签名证书、设备配对记录以及 LocalDevVPN / 安装通道可用。

## 手动在 GitHub 打包并发布到 Releases

上传源码到自己的 GitHub 仓库后：

1. 打开仓库的 **Actions** 页面。
2. 左侧选择 **SoulSign Manual Release**。
3. 点击 **Run workflow**。
4. 填写 `version`，例如 `1.1.0`。
5. `tag` 可以留空，留空时会自动使用 `v1.1.0`；也可以手动填写其他 Tag。
6. 点击绿色 **Run workflow** 开始构建。
7. 构建完成后进入仓库的 **Releases** 页面。

Release 会自动上传：

- `SoulSign.ipa`
- `SoulSign.ipa.sha256`
- `SoulSign-Info.plist`
- `SealTunnel-Info.plist`
- `SoulSign-source-<version>.zip`
- 对应源码压缩包 SHA-256

工作流只有 `workflow_dispatch` 触发器，因此提交代码、Push、PR 都不会自动打包或自动创建 Release。

## iOS 15 兼容性

- 主 App、`SealTunnel`、`DeviceSupport`、测试 Target 和 `Config/Base.xcconfig` 均设为 iOS 15.0。
- RustBridge 默认编译目标改为 iOS 15.0；Release 工作流会先检查 vendored RustBridge 的 minOS，不兼容时自动重建。
- 将 iOS 16 才有的 `NavigationStack` / `NavigationPath` 改为 iOS 15 可用的 `NavigationView` / `NavigationLink`。
- 将 `PhotosPicker` 改为 `PHPickerViewController`，将 `ShareLink` 改为 `UIActivityViewController`。
- 移除 iOS 16 才有的 sheet detent、drag indicator、`scrollDismissesKeyboard` 和新 toolbar visibility API。
- 增加 `Scripts/audit-ios15-compat.sh`，Release 构建前会自动检查常见 iOS 16-only API 是否重新出现。

## 一键覆盖上传到你的 GitHub 仓库

源码根目录提供：

`一键清空并上传到GitHub.bat`

双击后输入 `YES`，脚本会：

1. 删除当前目录旧 `.git`；
2. 建立全新的 `main` 根提交；
3. 绑定 `https://github.com/imylhbot/new.git`；
4. 使用 `git push --force` 用当前 SoulSign 源码覆盖远程 `main`。

这会替换远程 main 的代码和可见提交历史，但不会删除 GitHub Releases、Issues、仓库设置或已有 Actions 运行记录。

## 首次使用

1. 在 GitHub Releases 下载 `SoulSign.ipa`。
2. 使用你已有的签名方式首次把 SoulSign 安装到 iPhone。
3. 打开 SoulSign，在“我的”中添加一个或多个 Apple ID。
4. 导入当前设备的配对文件并配置 LocalDevVPN。
5. 导入 IPA，选择 Apple ID 后签名并安装。
6. 后续可以使用“立即续签”“续签全部”或在设置中开启“自动续签”。

## 目录说明

为了尽量降低对原工程签名、Minimuxer、Tunnel 和测试代码的破坏，本次二开保留了部分原始内部类型 / Target 名称，例如 `Seal`、`SealTunnel`、`isSeal`。这些属于内部实现名称，不影响安装后显示为 **SoulSign**，也不影响 Release 文件名。

## 安全说明

- Apple ID 密码不写入运行日志。
- 会话、证书私钥等敏感数据继续通过 Keychain / 受保护本地存储管理。
- 日志输出会通过 `LogPrivacyRedactor` 脱敏。
- 不要把真实证书、`.p12`、`.mobileprovision`、Apple 登录凭据或设备配对文件提交到公开 GitHub 仓库。

## License

SoulSign 的二次开发代码继续受原仓库 `LICENSE` 中的 GNU Affero General Public License v3.0 约束。

## GitHub 手动 Release 构建速度

SoulSign 的最低系统为 iOS 15.0。上游仓库附带的 RustBridge 预编译库最低为 iOS 16，因此第一次在一个全新的 GitHub Actions 缓存环境中构建时，会自动把 RustBridge 重编译为 iOS 15 版本，这一步通常是整个首次构建中最耗时的部分。

当前 `SoulSign Manual Release` 会在 RustBridge 重编译成功后**立即保存 iOS 15 缓存**，即使后面的 Swift/Xcode 编译失败也不会丢掉这个缓存。后续使用相同 RustBridge 源码再次手动 Release 时，会直接复用已经生成的 iOS 15 XCFramework，从而跳过 Rust 重编译。同时 Swift Package 下载目录也会单独缓存。

如果 Xcode 编译失败，Actions 页面会在日志末尾输出 `SoulSign Xcode error summary`，并尝试上传 `SoulSign-xcodebuild-log-*` 日志 artifact，便于直接定位真实编译错误，而不是只看到 `exit code 65`。
