# 打包与发布说明

## 环境要求

推荐版本：

- Flutter：3.41.9 或项目当前兼容版本。
- Dart：3.11.x。
- Android：JDK、Android SDK、Gradle。
- Windows：Windows 主机、Visual Studio C++ Build Tools、Inno Setup 6、fastforge。
- iOS：macOS、Xcode、CocoaPods、Apple Developer 账号。

## 通用检查

```bash
flutter pub get
flutter analyze
```

提交前至少执行 `flutter analyze`。涉及平台资源、原生配置或发布产物时，需要执行对应平台构建。

## Android APK

```bash
flutter build apk --release
```

默认产物：

```text
build/app/outputs/flutter-apk/app-release.apk
```

建议发布时复制到：

```text
out/BflyVPN-Android-<version>-app-release.apk
```

并生成：

```bash
sha256sum out/BflyVPN-Android-*.apk > out/<file>.sha256
```

## Windows Release 目录

必须在 Windows 主机或 Windows 侧 Flutter 工具链执行：

```powershell
flutter build windows --release --target lib/main_prod.dart
```

产物目录：

```text
build\windows\x64\runner\Release
```

应包含：

- `BflyVPN.exe`
- `HiddifyCli.exe`
- `hiddify-core.dll`
- `flutter_windows.dll`
- `data/`

说明：`HiddifyCli.exe` 和 `hiddify-core.dll` 是当前核心运行时的内部遗留文件名，只作为客户端运行依赖保留，不作为对外品牌展示。

## Windows 安装包

使用 fastforge + Inno Setup：

```powershell
fastforge --no-version-check package --platform windows --targets exe --skip-clean --build-target lib/main_prod.dart
```

fastforge 可能输出旧工程名格式的临时文件，例如：

```text
dist/<version>/<legacy-name>-<version>-windows-setup.exe
```

发布前必须统一重命名为 BflyVPN 格式。

最终发布命名：

```text
out/BflyVPN-Windows-Setup-x64.exe
```

如果脚本在中文路径上出现编码错误，可以手动复制 Inno Setup 成功生成的 exe 到 `out/`。

## Windows 便携包

将 release 目录压缩为：

```text
out/BflyVPN-Windows-Portable-x64.zip
```

zip 内部根目录应为：

```text
BflyVPN/
```

并包含 `BflyVPN.exe` 与核心 DLL/EXE。

Linux/WSL 中可用示例：

```bash
python3 - <<'PY'
from pathlib import Path
import zipfile
src = Path('/mnt/e/codex_build/butterfly-client/build/windows/x64/runner/Release')
out = Path('out/BflyVPN-Windows-Portable-x64.zip')
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
    for p in sorted(src.rglob('*')):
        if p.is_file():
            zf.write(p, f'BflyVPN/{p.relative_to(src).as_posix()}')
PY
```

## Windows 产物校验

```bash
sha256sum out/BflyVPN-Windows-Setup-x64.exe > out/BflyVPN-Windows-Setup-x64.exe.sha256
sha256sum out/BflyVPN-Windows-Portable-x64.zip > out/BflyVPN-Windows-Portable-x64.zip.sha256
```

便携包至少检查：

- `BflyVPN/BflyVPN.exe`
- `BflyVPN/HiddifyCli.exe`
- `BflyVPN/hiddify-core.dll`
- `BflyVPN/flutter_windows.dll`

## iOS 测试包

iOS 必须在 macOS 执行。推荐先同步仓库到 Mac：

```bash
rsync -av --exclude build --exclude .dart_tool --exclude ios/Pods --exclude ios/.symlinks \
  /path/to/butterfly-client/ user@mac:/Users/user/works/butterfly-client/
```

Mac 上执行：

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

正式分发或给团队成员安装需要 Apple Developer 账号、证书、描述文件或 TestFlight。

## 发布前检查清单

- [ ] `flutter analyze` 无问题。
- [ ] Android APK 可安装并登录。
- [ ] Windows exe 安装包可安装启动。
- [ ] Windows portable zip 解压后可启动。
- [ ] 登录、注册、忘记密码可用。
- [ ] 普通用户/到期用户点击加速提示开通或续费，不进入连接。
- [ ] 会员用户可同步节点并连接。
- [ ] 版本检查能读取后台配置。
- [ ] UI 不显示原上游品牌和技术敏感信息。
