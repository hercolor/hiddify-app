# BflyVPN 客户端变更记录

本文件记录 BflyVPN 二次开发后的产品变更。旧上游通用客户端的发布记录不再作为当前项目的主变更记录。

## 当前版本

当前客户端版本以 `pubspec.yaml` 的 `version` 为准。

## 已完成的二次开发能力

### 品牌与平台

- 产品名称统一为“BflyVPN”。
- Android 包名保持 `pro.y88.accelerator`。
- iOS 主 App Bundle ID 为 `pro.y88.hudiejiasu`，Network Extension 为 `pro.y88.hudiejiasu.PacketTunnel`。
- Windows 可执行文件为 `BflyVPN.exe`。
- 图标资源已替换为 BflyVPN 图标。
- 启动页当前保持白屏，等待正式启动页设计。

### 账号与会员

- 对接 `https://api.y88.pro` XBoard 后端。
- 支持邮箱/手机号登录。
- 支持注册页面对接后端 API。
- 支持忘记密码与验证码重置。
- 我的账号页展示会员、到期时间、设备数量等信息。
- 安全中心提供修改密码、绑定/更换手机入口。

### 节点与连接

- 登录成功后自动同步 XBoard 订阅节点。
- 支持节点列表、节点切换、一键延迟测试。
- 连接前刷新会员状态。
- 普通用户、会员到期、流量耗尽时阻止连接并提示开通或续费。
- 普通用户界面隐藏订阅地址、节点真实地址、协议、端口、DNS 等技术细节。

### 更新与发布

- 版本检查对接 `/api/app/v1/client-version`。
- Android 支持 release APK 打包。
- Windows 支持安装包和便携包。
- iOS 打包说明已更新到当前签名/测试流程。

## 后续记录规则

新增版本请按以下格式追加：

```markdown
## <version> - <YYYY-MM-DD>

### 新增
- ...

### 修复
- ...

### 调整
- ...

### 验证
- ...
```
