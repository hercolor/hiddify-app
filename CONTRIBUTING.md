# BflyVPN 客户端协作说明

本仓库现在按 BflyVPN 二次开发客户端维护，不再使用原上游通用客户端的贡献说明、Issue 链接和发布流程。

## 工作范围

当前客户端面向自有 XBoard 后端：

- 后端地址：`https://api.y88.pro`
- 产品名称：BflyVPN
- 用户路径：登录/注册 → 同步节点 → 查看会员 → 选择节点 → 一键加速
- 普通 UI 不展示订阅地址、节点真实地址、协议、端口、DNS、fake-ip、IPv6 等技术细节

## 修改原则

- 小步提交，避免一次性重写无关模块。
- 不硬编码生产 token、订阅地址、短信密钥或其它密钥。
- 不在日志中输出完整 `authData`、token、订阅 URL、节点密码或完整服务端地址。
- 涉及登录、会员、连接权限、版本更新的修改，必须同时检查 Android 和 Windows 行为。
- 内部仍保留的 `hiddifycore`、`HiddifyCli.exe`、`hiddify-core.dll` 等名称只代表运行时依赖，不作为对外品牌使用。

## 常用开发命令

```bash
flutter pub get
flutter analyze
```

Android：

```bash
flutter build apk --release
```

Windows：

```powershell
flutter build windows --release --target lib/main_prod.dart
fastforge --no-version-check package --platform windows --targets exe --skip-clean --build-target lib/main_prod.dart
```

更多打包说明见 [`docs/build-release.md`](docs/build-release.md)。

## 提交前检查

- 登录、注册、忘记密码流程没有破坏。
- 普通用户、会员到期、流量耗尽时不能真实连接。
- 会员用户可以同步节点并连接。
- 版本检查仍对接后台版本管理。
- 用户界面只显示“BflyVPN”品牌。
- 新增文档链接可打开，且不重新引入上游下载地址。

## 文档入口

- [`README.md`](README.md)
- [`README_cn.md`](README_cn.md)
- [`docs/client-overview.md`](docs/client-overview.md)
- [`docs/backend-integration.md`](docs/backend-integration.md)
- [`docs/build-release.md`](docs/build-release.md)
