# SoulSign iOS 15 Build Fix

本次修复针对 GitHub Actions Run `36327286362` 中的 Xcode `exit code 65`。

实际编译错误不是 `65` 本身，而是源码仍包含 iOS 16 才提供的 Foundation URL API：

- `URL.appending(path:directoryHint:)`
- `URL(filePath:)`
- `PresentationDetent`

本版已经统一改为 iOS 15 可用的：

- `URL.appendingPathComponent(_:isDirectory:)`
- `URL(fileURLWithPath:)`
- 删除未使用的 `PresentationDetent` 辅助代码

并扩展 `Scripts/audit-ios15-compat.sh`，以后这些 API 再次进入源码时会在 Xcode 编译前直接失败并指出原因。

构建速度方面：旧工作流每次失败都会重新构建 RustBridge，Run 36327286362 中该步骤从 14:49:26 到 14:58:07，约 8 分 41 秒。新版把 iOS 15 RustBridge XCFramework 在重编成功后立即写入 GitHub Actions Cache，因此即使后续 Xcode 编译失败，下一次也可以直接复用。Swift Package 下载也增加了独立缓存。
