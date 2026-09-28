SoulSign iOS 登录错误处理修正版

基线：imylhbot/new，e107083475ea9d0c22842e76069a37b1a2283aa0。
此包不是 IPA，不能直接安装到手机；不是对 Apple 登录恢复的保证。

使用：
1. 在你的 iOS 工程中备份对应文件。
2. 如果仍使用上述基线，把本包的 Seal 和 SealTests 目录合并覆盖到工程根目录。
   如果工程已有新的修改，请审阅 changes.patch 后应用，避免覆盖你后来的工作。
   可选补丁方式：git apply --ignore-space-change changes.patch
   两种方式选一种，先前 PC 包里的 ios-diagnostics.patch 不要重复叠加。
3. 提交更新到原仓库 imylhbot/new，运行现有 SoulSign Manual Release 工作流。
4. 下载新构建的 SoulSign.ipa，使用与你现有应用相同的账号/Bundle ID 更新安装。
   不要为了测试先卸载旧版，卸载会移除其本地数据。
5. 重新添加账号，记录新提示中的错误码和“我的 → 运行日志”中的错误文字。

修改内容：
- Apple 拒绝 Anisette 时显示 SEAL-AUTH-107i，不再绕过分类落入“验证失败”。
- 去掉已经没有对应重试逻辑的远程重试分支，Apple 响应错误进入原有分类流程。
- 保留认证阶段和底层错误码，对错误详情做隐私脱敏。
- Apple 返回账号及团队后，本机保存失败显示 SEAL-AUTH-STORE-001。
- 取消本地 Anisette 请求时保持取消状态，不伪装成环境生成失败。
- 添加错误码保留/邮箱脱敏测试，修正已有团队错误码测试的预期。

如何判断下一步：
SEAL-ANI-114：本地 Anisette 生成失败，需要看其具体错误。
SEAL-AUTH-107i：Apple 拒绝 Anisette 数据，需要查登录环境，不能直接认定密码错误。
SEAL-AUTH-102a：Apple 返回账号或密码无效。
SEAL-AUTH-101：验证码无效。
SEAL-AUTH-105f：认证后获取开发团队失败。
SEAL-AUTH-STORE-001：认证已通过，本机钥匙串或账号记录保存失败。

配对与登录互相独立。UDID/配对用于设备连接，不会代替 Apple 账号认证。
本次没有重置 Anisette 设备身份，也没有强制切换远程服务。
没有修改线上仓库、触发 GitHub 构建或生成新的 IPA。

验证：git diff --check、补丁反向应用检查通过。
当前是 Windows 环境，没有 Xcode，新增 Swift 测试未运行、iOS 未编译、真机登录未验证。
因此这次确认修复的是错误处理缺陷。截图中的实际登录故障仍需底层错误码确认。
原项目许可证 AGPL-3.0，见 LICENSE。
