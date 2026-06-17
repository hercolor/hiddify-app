# 蝴蝶加速 Client

蝴蝶加速客户端是基于 Flutter 二次开发的商业加速客户端，面向 Android、Windows、iOS、macOS 等平台。当前仓库已经不再作为原 Hiddify 通用开源客户端维护，文档、发布包、UI、账号体系和后端集成都以蝴蝶加速业务为准。

## 当前定位

- 产品名称：蝴蝶加速
- 后端面板：`https://api.y88.pro`
- 账号系统：XBoard 用户体系
- 节点系统：XBoard 订阅 + Xboard-Node
- 客户端版本：见 `pubspec.yaml` 的 `version`
- 普通用户入口：主页、节点、会员/我的账号
- 技术/诊断入口：仅用于内部排查，不作为普通用户功能展示

## 已完成的二次开发能力

### 账号与会员

- 邮箱/手机号登录。
- 注册页对接后端注册 API。
- 忘记密码与验证码重置。
- 登录后自动同步订阅节点。
- 我的账号页展示会员套餐、到期时间、设备数量、安全中心。
- 安全中心包含修改密码、绑定/更换手机。
- 非会员、过期、流量耗尽状态会阻止连接并提示开通/续费会员。

### 连接与节点

- 登录成功后从 XBoard 返回的订阅地址同步节点。
- 支持节点列表、当前节点显示、节点切换。
- 支持一键连接/断开。
- 连接前刷新会员状态，避免到期账号继续连接。
- 客户端隐藏订阅地址、节点协议、服务端地址、端口、DNS 等普通用户不需要看到的技术信息。

### UI 与品牌

- 品牌统一为“蝴蝶加速”。
- Android / Windows / iOS / macOS / Web 图标已替换为项目根目录 `icon.png` 派生资源。
- Android 和 Windows 使用一致的登录、注册、会员、安全中心、关闭弹窗设计。
- 启动页当前保持白屏，后续有正式启动页设计后再加入品牌动效或图片。

### 更新与发布

- 客户端版本检查对接 `https://api.y88.pro/api/app/v1/client-version`。
- Windows 支持安装包和便携包。
- Android 支持 release APK 打包。
- iOS 需要在 macOS/Xcode 环境下使用开发者账号签名打包。

## 重要目录

| 路径 | 说明 |
| --- | --- |
| `lib/features/auth/` | 登录、注册、会员、账号、安全中心 |
| `lib/features/home/` | 主页与一键连接入口 |
| `lib/features/proxy/` | 节点列表、节点选择、延迟显示 |
| `lib/features/connection/` | 连接状态机和连接前权限/会员检查 |
| `lib/core/model/constants.dart` | 后端 API、更新地址、协议/隐私链接 |
| `assets/config/app_config.json` | XBoard API 基础地址 |
| `android/` | Android 原生壳、包名、图标、启动页 |
| `windows/` | Windows 原生壳、安装包配置、图标 |
| `ios/` | iOS App 与 Network Extension 配置 |
| `docs/` | 当前二开客户端文档 |
| `out/` | 本地构建产物输出目录 |

## 构建要求

基础要求：

- Flutter 3.41.9 或当前项目锁定的兼容版本。
- Dart 3.11.x。
- Android 构建需要 Android SDK / JDK / Gradle 环境。
- Windows 安装包需要 Windows 主机、Visual Studio C++ 工具链、Inno Setup。
- iOS 需要 macOS、Xcode、Apple Developer 账号或本机测试签名能力。

常用命令：

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

Windows 在 Windows 主机或 WSL 调用 Windows 工具链时执行：

```powershell
flutter build windows --release --target lib/main_prod.dart
fastforge --no-version-check package --platform windows --targets exe --skip-clean --build-target lib/main_prod.dart
```

更多构建说明见：[`docs/build-release.md`](docs/build-release.md)。

## 发布产物命名

当前本地发布产物建议统一放到 `out/`：

- `蝴蝶加速-Android-*.apk`
- `蝴蝶加速-Windows-Setup-x64.exe`
- `蝴蝶加速-Windows-Portable-x64.zip`
- `蝴蝶加速-Windows-x64.msix`（如启用 MSIX）

每个产物建议同步生成 `.sha256` 校验文件。

## 后端接口概览

客户端依赖 XBoard 兼容 API：

- 登录：`/api/v1/passport/auth/login`
- 注册：`/api/v1/passport/auth/register`
- 忘记密码：`/api/v1/passport/auth/forget`
- 用户信息：`/api/v1/user/info`
- 版本检查：`/api/app/v1/client-version`
- 规则集/更新相关地址：由 `lib/core/model/constants.dart` 和 `lib/core/config/locked_core_config.dart` 控制

详细集成说明见：[`docs/backend-integration.md`](docs/backend-integration.md)。

## 文档索引

- [`docs/client-overview.md`](docs/client-overview.md)：客户端二开总览。
- [`docs/backend-integration.md`](docs/backend-integration.md)：XBoard/API/订阅同步说明。
- [`docs/build-release.md`](docs/build-release.md)：Android、Windows、iOS 打包说明。
- [`docs/butterfly_accelerator_UI_UX_Design_Spec.md`](docs/butterfly_accelerator_UI_UX_Design_Spec.md)：早期 UI/UX 设计稿，仅作为历史参考。

## 维护规则

- 不在普通 UI 展示订阅地址、节点真实地址、端口、协议、DNS、fake-ip、IPv6 等技术细节。
- 不在日志中输出完整 `authData`、token、订阅地址、节点密码或完整服务端地址。
- Android `applicationId` 当前保留为 `pro.y88.accelerator`，不要随意修改，避免影响已安装用户覆盖升级。
- iOS 当前主 App Bundle ID 为 `pro.y88.hudiejiasu`，Network Extension 为 `pro.y88.hudiejiasu.PacketTunnel`。
- 正常用户页面以 Home / Nodes / Membership 为主；技术设置仅作为内部诊断或隐藏功能。

