如果下载的是 Actions 中的 SoulSign-Windows-x64.zip：解压后直接运行 SoulSign-PC.exe。
以下源码脚本在单独源码包 Windows/PC 内。

SoulSign PC 1.3.1 修复版 — 安装与配对
===================================
日常只需双击“启动SoulSign-PC.bat”，不需要运行“安装依赖”或“源码启动”。
本次修复 Python 探测失败导致 PowerShell 中断；没有兼容 Python 时自动使用便携版。
“安装依赖”在没有兼容 Python 时会说明便携版无需依赖并正常结束。

界面默认只有两个入口：① 安装 IPA；② 配对手机。
原有续签、环境检测和日志保留在“显示 / 隐藏高级功能”内。

手机已有 SoulSign：直接配对即可，不必重装，不需要 Apple ID。
1. USB 连接并解锁 iPhone，在手机点击信任；PC 顶部重新检测并选择该设备。
2. 打开“② 配对手机” → “查找手机中已安装的 SoulSign”。
3. 选择正确 SoulSign，点击“生成配对文件并写入 SoulSign”。
4. iPhone 打开/重新进入 SoulSign → 我的 → 设备 → 检查配对状态。
   文件在 Documents/SoulSignPairing.mobiledevicepairing，手机代码会自动接收并删除收件文件。
   PC 的“已写入”仅代表传输成功。手机端本地 VPN/隧道通道仍须按其提示配置并验证。
5. UDID 从 USB 设备服务读取，写入文件的 UDID 字段；手机导入时读取它。
   不需要你手填，也不把广告标识 IDFA / identifierForVendor 当作 UDID。

直接写入失败的备用方法：
PC 点击“导出配对文件”，保留 SoulSignPairing.mobiledevicepairing 文件名。
可在 iTunes → 设备 → 文件共享 → SoulSign → 添加文件，然后手机重新进入 SoulSign。
如果 iTunes 看不到 SoulSign 文件共享，先把配对文件通过自己的 iCloud Drive 等方式
保存到 iPhone“文件”应用，再点击截图中的“导入配对文件”选取。
配对文件包含设备信任密钥，不要公开或发给陌生人。

手机 Apple ID 返回 503：
本次完整包的 iOS 源码已增加明确的暂不可用提示，并在尚未进入 2FA 时最多重试两次。
服务持续返回 503 时无法保证登录成功。不要因此删除配对文件或账号。
必须重新运行 iOS 工作流并安装新 IPA 才能获得手机端修改。


配对生成及手机写入尚未经过真实 USB iPhone 验收。
iOS 17+ 生成 RemotePairing 密钥；失败时明确报错，不冒充已激活或静默退回旧格式。
iOS 15/16 使用 USB Lockdown 配对记录。

--- 以下为保留的运行、源码和许可说明 ---

SoulSign PC 1.3.1 — Windows 10/11 x64
===================================

推荐：解压全部文件后，双击「启动SoulSign-PC.bat」。
有 portable\SoulSign-PC.exe 时直接运行便携版，不要求安装 Python、Flutter、Visual Studio。
不要只复制 exe，必须保留旁边的 _internal 文件夹。

首次使用
1. 解压到固定目录，例如 D:\SoulSign-PC，不要在 ZIP 内直接运行。
2. 你已有 iTunes：保留它，连接 iPhone 的 USB 数据线，解锁手机并点击“信任”。
3. 双击「启动SoulSign-PC.bat」。启动时检测 Python 运行时、Apple Mobile Device
   Service、USB 设备、Trust。检测未通过时，查看“首次检测”页，并重新检测。
   服务缺失/停止时，请修复 iTunes 或在 Windows 服务管理器中启动 Apple Mobile Device Service。
4. “签名安装”页添加 Apple ID，输入密码和可信设备/短信收到的 2FA 验证码。
   多个账号分别添加；每次安装前选定账号。无需把密码提供给开发者。
5. 选择或拖入你自己的 IPA，选择目标 USB iPhone，点击“签名并安装”。
6. 在 iPhone 按系统提示信任开发者；系统要求时开启开发者模式。

源码启动 / 安装依赖
双击「安装依赖.bat」创建 .venv 并安装依赖；双击「源码启动.bat」启动 Python GUI。
支持官方 Python 3.11/3.12 x64（需 pip、venv、Tcl/Tk）。优先自动选择 3.12。
Python 3.13/3.14 的部分传递依赖缺少 Windows wheel，因此源码脚本不会选用它们。
只有这些 Python 版本时可直接用便携版，无需修改现有 Python。
首次安装依赖需要联网，失败后修复网络/代理并重试；脚本不会继续伪装成安装成功。
脚本不会修改 GitHub 仓库，也不会清空任何已有仓库。

续签
本机成功安装的应用出现在“应用 / 自动续签”页，可续签所选或“一键刷新全部”。
引擎保存原签名 Team，续签时找回原账号；账号失效需重新登录。
原始 IPA 会复制到 %LOCALAPPDATA%\SoulSign-PC\originals，删除此缓存会影响续签。
默认免费账号模式会移除 .appex / Watch 扩展；不承诺保留 SoulSign iOS 隧道扩展功能。
本版本不提供付费开发者扩展分别签名或多 Team 手动选择界面。

自动 / 后台续签
勾选程序内自动续签后，程序运行期间每小时检查一次，可提前 1/2/3 天刷新。
点击“启用 Windows 后台计划”可让窗口关闭后仍由计划任务每小时检查。
任务以当前用户、普通权限、交互登录模式运行；无需保存 Windows 密码。
电脑必须开机、该用户处于登录状态、手机 USB 可连接、网络和 Apple 会话有效。
关机、睡眠、用户注销、手机断开、Apple 要求再次 2FA 时无法保证续签。
程序正在执行另一个操作时，后台任务会跳过，下一轮重试。
关闭后台计划使用界面按钮。移动/删除便携目录前先关闭计划，再在新目录重新启用。
任务名称为 SoulSign-PC-<当前用户 SID>。首次计划在启用约两分钟后开始。

日志与本地数据
“运行日志”支持查看、复制、清除。日志轮转大小 2MB，保留两个备份。
会话和待验证的 2FA 状态使用 Windows DPAPI 加密，仅当前 Windows 用户可解密。
密码不落盘、不作为命令行参数；登录后只保留加密会话。
签名私钥/证书和配对记录由引擎保存在本机文件中，不等同于 DPAPI 加密会话；
请勿共享 %LOCALAPPDATA%\SoulSign-PC 或设备配对记录。运行日志会脱敏邮箱、设备号和常见敏感字段。
移除账号删除其登录会话，不会自动吊销 Apple 证书或删除已安装应用。

网络依赖
登录和申请证书/描述文件需要访问 Apple 服务；首次登录的 Anisette 组件从引擎
内置上游地址 https://anisette.dl.mikealmel.ooo 下载并缓存。
该下载服务不是 Apple 登录代理；Apple ID 登录请求由本机发往 Apple。
第三方组件下载或 Apple 服务不可用时会报错，不能仅凭已安装 iTunes 保证成功。

构建 EXE
双击 build_windows.bat，使用 .venv + PyInstaller 构建 dist\SoulSign-PC。
不要求 Flutter/Visual Studio；zsign 官方 Windows x64 二进制已包含在源码目录。
requirements.txt 固定直接依赖；requirements-tested.txt 记录本次完整构建环境。
tests\test_desktop.py 为账号存储、续签控制、并发及脱敏测试。

验证范围
参见完整包根目录 VALIDATION.txt。真实 Apple ID + 2FA、申请开发证书、真机签名安装和跨天后台
续签需要真实账号及 USB iPhone 验收。本包不能声明这些已在你的手机上通过测试。
未包含 SoulSign.ipa；请使用仓库 Release 中的 IPA 或你已下载的文件。

源码来源与许可证
用户仓库：https://github.com/imylhbot/new
基线 commit：e107083475ea9d0c22842e76069a37b1a2283aa0
Python 引擎：pwnapplehat/iPASide，固定 7f13ecdb8f8e2737c0a5483ea551e970b9d4d5b7（MIT）。
图标直接复用用户仓库 SoulSignIcon-1024.png，未重绘。
新增 Python 界面/适配代码按仓库 GNU AGPL-3.0 提供；原组件保留各自许可证。
zsign 1.1.2 来自 zhlynn/zsign 官方 Release，已对比官方 SHA256SUMS。
压缩包哈希：96b5bf7029a52c67cdb78b68b3666d8ff1e31e5c435535964be2a482afc09e5c
引擎修改：SoulSign 命名/独立数据目录、DPAPI 会话、中文 Tk 界面、缓存和任务适配。
所有源码、构建配置和第三方许可随包提供；详见 licenses 和 config.json。
