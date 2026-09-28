SoulSign 双端构建修复

对应三个日志错误：
1. OLDPWD: unbound variable
   校验脚本在进入临时目录前把 XCFramework 目录解析为绝对路径；不再依赖 OLDPWD。
2. Rust llvm-nm was not found
   Ensure RustBridge 步骤无论缓存命中与否，都安装固定 RUST_TOOLCHAIN 的
   llvm-tools-preview，并设置 RUSTUP_TOOLCHAIN，确保 rustc 和 llvm-nm 来自同一工具链。
3. MSYS2 Copying skeleton files 混入 cd 路径
   移除登录 Shell 输出解析及 cygpath，改为 PowerShell Push-Location 后启动
   bash --noprofile --norc ./tools/zsign/build-zsign.sh。构建脚本自行设置 MinGW PATH。

怎么应用：
将本包以下三个文件覆盖到仓库根目录相同路径：
  Scripts/verify-rustbridge-minos.sh
  .github/workflows/release.yml
  Windows/build-soulsign-windows.ps1
注意 .github 是目录，解压/上传时不要遗漏。
如果你已自行修改过工作流，请审阅 changes.patch 后合并，避免覆盖新改动。
也可用 git apply --ignore-space-change changes.patch；不要同时覆盖文件后再应用补丁。

提交到原仓库 imylhbot/new 后，到 Actions → SoulSign Manual Release → Run workflow
选择含新提交的分支重新启动。不要仅点旧任务的 Re-run jobs，旧任务仍可能使用旧提交。
不需要清缓存，现有 iOS 15 RustBridge 缓存继续使用。
无需为了本次错误再次重编已确认兼容的 RustBridge；安装 LLVM 检查工具不等于重编库。

此包仅包含三个构建文件，不覆盖前一版手机登录修改。
它修复的是现有 Flutter Windows 构建工作流；之前提供的 Python 精简便携版
是另一个本地打包产物，本包不会自动把 CI Windows 界面替换为 Python 版。
没有直接上传 GitHub，也没有启动远程构建。

验证范围：
- YAML 解析、工具链设置/安装顺序检查通过。
- Windows PowerShell 脚本语法解析通过。
- git diff --check 和补丁反向应用检查通过。
- 准备了路径回归测试，但当前 Windows 沙箱阻止 Git Bash 创建 signal pipe
  （Win32 error 5），无法在本环境执行 Bash 回归测试。
- 没有 macOS/Xcode 或完整 MSYS2/Flutter 构建环境，尚未验证 GitHub 双端构建成功。

原工程许可证：AGPL-3.0（随包 LICENSE）。
