SoulSign 完整修复包（iOS 源码 + Python PC 1.3.1 便携版）
基于 imylhbot/new 的 bddbbd07f305e35ed11d375684b75abdfd809722。

一、直接使用 PC
解压全部文件，双击根目录“启动SoulSign-PC.bat”。便携版自带 Python，日常无需安装依赖。
Windows/PC/src 是完整 PC GUI 与 iPASide 引擎源码；Windows/PC/portable 是已构建程序。
图标沿用 SoulSign。需要 iTunes/Apple Mobile Device Service 和 USB 信任。
源码启动/本地构建需要 Python 3.11/3.12 x64（含 Tk）；启动脚本会安全探测已安装版本。
详细登录、续签、日志及配对步骤见 Windows/PC/README-中文.txt。

二、手机配对与 UDID
手机已有 SoulSign 时无需重装或登录 Apple ID 即可配对。
USB 连接并解锁手机，点击“信任”；PC 选择设备 → ② 配对手机 → 查找已安装 SoulSign
→ 选择应用 → 生成配对文件并写入 SoulSign。
手机重新进入“我的 → 设备”，再检查配对状态。PC 写入成功不代表手机隧道已激活。
UDID 由 PC 通过设备服务读取并随配对文件传入，手机不需要自行猜测或手填。
备用：导出 SoulSignPairing.mobiledevicepairing，通过自己的“文件”应用导入，或 iTunes 文件共享。
配对密钥不要上传 GitHub。
注意：PC 免费账号模式会移除 appex/Watch；若移除了 SoulSign 的 VPN 扩展，不能声称完整手机端隧道功能可用。

三、iOS 503 登录报错
日志中的 ALTServerError/code 1 包含 HTTP 503 HTML，并非明确的密码错误。
手机源码增加 SEAL-NET-503 提示；尚未进入 2FA 时最多等待 2 秒、4 秒重试两次，
保持相同本地 Anisette 数据，进入验证码流程后不自动重试。
持续返回 503 时仍需要等待服务恢复或检查网络/代理；程序不能保证 Apple 服务恢复。
账号和配对文件不会因为该暂时错误而失效。不需要为此删除它们。
修改必须重新构建并安装新 IPA 才生效。包内没有冒充已修复的新 IPA。

四、为什么原下载为 392 MB
392,548,009 字节是 Actions artifact 总大小，不是 SoulSign.ipa 的单独大小。
旧流程把源码 ZIP 和 IPA 放进同一个 artifact；源码用 rsync 拷贝工作目录，
未排除 Rust target 编译缓存。新流程仅打包 Git 跟踪的源码文件，源码单独上传。
Actions 下载 soulsign-ios-release 仅含 IPA/校验/Info；soulsign-source-release 是源码；
soulsign-windows-release 是 Python PC 便携 ZIP。完整源码保留必需的 vendored RustBridge 库。

五、PC 构建问题
完整日志显示 openssl.pc 找不到：setup-python 的 PKG_CONFIG_PATH 干扰 MSYS2。
新 Windows 工作流从 Windows/PC 本地源码用 PyInstaller 构建，不再克隆 Flutter GUI 或编译 zsign。
附官方 zsign 1.1.2 exe 与 SHA256 校验、许可证和源代码；无需最终用户安装 Flutter/Visual Studio。

六、一键上传和清理
“清理构建缓存.bat”只清除本包内指定构建目录和源码 venv，不删账号、配对密钥、便携程序、Git 或备份。
“一键上传到GitHub.bat”固定使用 imylhbot/new：临时克隆 main → 备份完整 Git bundle
→ 按 SOURCE-MANIFEST.txt 替换受跟踪源码 → 显示改动 → 输入 UPLOAD → 提交并正常推送。
需要 Git for Windows 及该仓库的 GitHub 登录权限（首次可由 Git Credential Manager 弹浏览器）。
不强推、不抹除历史；远程有并发更新或分支保护时停止并显示 Git 错误。
旧名称“一键清空并上传到GitHub.bat”现在调用相同安全流程，不再删除 .git。
portable、缓存、私密账号文件不列入上传清单；GitHub Actions 会重新生成 PC exe。
上传成功后 Actions → SoulSign Manual Release → Run workflow → main；版本可填写 1.3.1。
不要只点击旧运行的 Re-run jobs，那会复用旧源码。

七、验证范围
Windows 实际构建、自检、测试结果见 VALIDATION.txt。
iOS 修改在 Windows 无法用 Xcode 编译，需 Actions 验证；未用真实 Apple ID 或连接 iPhone 验证安装/隧道。
这是完整源码与可启动 PC 包，不等于已完成真机端到端验收。
许可证：主项目 AGPL-3.0；iPASide/zsign 等第三方许可证见 Windows/PC/licenses 与 third_party。
