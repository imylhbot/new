# SoulSign PC

The default Windows release now builds the vendored Python GUI in `PC/`.
It no longer clones the Flutter GUI or compiles zsign under MSYS2.

Build on Windows with Python 3.12 x64:

```powershell
.\Windows\build-soulsign-windows.ps1 -Version 1.3.1
```

Output: `build/windows/SoulSign-Windows-x64.zip` (portable executable and licenses).
The complete source archive includes `PC/src`, `PC/third_party`, build scripts and dependencies.
The official zsign 1.1.2 executable is checked against `PC/zsign.sha256` before building.
See the root Chinese README for pairing, GitHub upload, and verification limits.
