# BflyVPN 客户端

本仓库已经完成 BflyVPN 业务二次开发，不再使用原 Hiddify 通用开源客户端文档作为主说明。当前客户端服务于 `api.y88.pro` 的 XBoard 后端、会员体系和节点订阅体系。

## 产品信息

- 名称：BflyVPN
- 后端：`https://api.y88.pro`
- 账号：邮箱/手机号登录，注册后登录使用
- 会员：普通用户、会员到期、BflyVPN 月卡、BflyVPN 季卡、BflyVPN 年卡等状态
- 平台：Android、Windows；iOS/macOS 保留并按需打包
- 版本：见 `pubspec.yaml`

## 核心功能

- 登录、注册、忘记密码。
- 个人中心：会员套餐、到期时间、设备数量。
- 安全中心：修改密码、绑定/更换手机号。
- 登录后自动拉取订阅并同步节点。
- 节点列表、节点切换、一键测试延迟。
- 一键加速，连接前检查会员状态。
- 会员过期、普通用户、流量耗尽时禁止连接并提示开通/续费。
- Windows 托盘、关闭弹窗、安装包和便携包。
- 客户端版本检查与后端版本管理对接。

## 主要文档

- [客户端总览](docs/client-overview.md)
- [后端集成说明](docs/backend-integration.md)
- [打包发布说明](docs/build-release.md)
- [UI/UX 历史设计稿](docs/butterfly_accelerator_UI_UX_Design_Spec.md)

## 常用命令

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

Windows 打包在 Windows 环境执行：

```powershell
flutter build windows --release --target lib/main_prod.dart
fastforge --no-version-check package --platform windows --targets exe --skip-clean --build-target lib/main_prod.dart
```

产物统一放到 `out/`：

- `BflyVPN-Windows-Setup-x64.exe`
- `BflyVPN-Windows-Portable-x64.zip`
- `*.sha256`

## 维护注意事项

- 普通用户界面不得展示订阅地址、节点真实地址、协议、端口、DNS、fake-ip、IPv6 等技术信息。
- 日志必须脱敏，不输出完整 token、authData、订阅 URL、节点密码。
- Android `applicationId` 当前是 `pro.y88.accelerator`，为兼容已安装用户不要随意改动。
- iOS 主 App Bundle ID 是 `pro.y88.hudiejiasu`，扩展是 `pro.y88.hudiejiasu.PacketTunnel`。
- 启动页当前保持白屏，后续等正式启动页设计再接入。
