# 蝴蝶加速客户端发布说明

本发布面向蝴蝶加速二次开发客户端。请从当前发布附件或后台版本管理配置的下载地址获取安装包。

## 推荐下载

| 平台 | 文件 |
| --- | --- |
| Android | `蝴蝶加速-Android-*.apk` |
| Windows 安装包 | `蝴蝶加速-Windows-Setup-x64.exe` |
| Windows 便携包 | `蝴蝶加速-Windows-Portable-x64.zip` |
| Windows MSIX | `蝴蝶加速-Windows-x64.msix`（如启用） |
| iOS | 通过 TestFlight、企业签名或开发者签名分发 |

## 校验

发布附件应同时提供 `.sha256` 文件。下载后可用以下命令校验：

```bash
sha256sum -c <file>.sha256
```

## 升级注意

- Android 包名保持 `pro.y88.accelerator`，用于覆盖升级旧版本。
- Windows 可执行文件为 `蝴蝶加速.exe`。
- 客户端版本需要与后台版本管理接口保持一致，否则用户端不会提示升级。
- 普通用户界面不展示订阅地址、节点真实地址、协议、端口、DNS 等技术信息。

## 文档

- `README.md`
- `README_cn.md`
- `docs/client-overview.md`
- `docs/build-release.md`
- `docs/backend-integration.md`
