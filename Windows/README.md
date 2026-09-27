# SoulSign PC

SoulSign 1.3.0 起采用 iOS + Windows 双端发布。

Windows 版用于第一次把 SoulSign.ipa 安装到 iPhone，也可以直接给其他 IPA 使用 Apple ID 签名、安装和续签。

## Release 产物

手动运行 GitHub Actions 的 SoulSign Manual Release 后，Release 至少包含：

- SoulSign.ipa
- SoulSign-Windows-x64.zip
- SoulSign-Setup-<version>-x64.exe
- SHA256SUMS.txt

## Windows 功能

Windows 端基于 MIT 许可的 iPASide Windows 代码库构建，并在 CI 中固定到经过审核的上游 commit，再应用 SoulSign 品牌和更新源。

主要能力：

- Windows 10 / 11 x64
- USB / Wi-Fi 发现 iPhone / iPad
- Apple ID 登录和双重认证
- 多 Apple ID
- 自动创建证书、App ID 和 Provisioning Profile
- IPA 签名并直接安装
- 已安装应用续签
- Windows 后台自动续签
- pairing file 工具
- 日志与诊断

## 首次使用

1. Windows 安装 Apple 的 Apple Devices 应用，或安装 iTunes。
2. USB 连接 iPhone，解锁并选择“信任此电脑”。
3. 下载并运行 Release 中的 SoulSign-Setup-<version>-x64.exe。
4. 添加 Apple ID。
5. 选择 SoulSign.ipa。
6. 点击签名并安装。

免费 Apple ID 仍受 Apple 的免费开发签名限制，包括签名有效期和可安装应用数量。

## 构建来源与许可证

Windows 侧载核心固定来源：

- upstream: pwnapplehat/iPASide
- commit: 7f13ecdb8f8e2737c0a5483ea551e970b9d4d5b7

该上游项目使用 MIT License。许可证原文保存在
Windows/THIRD_PARTY_iPASide_LICENSE.txt，并随 Windows ZIP 一起发布。
