# 后端集成说明

## 后端地址

当前客户端默认连接：

```text
https://api.y88.pro
```

配置位置：

- `assets/config/app_config.json`
- `lib/core/model/constants.dart`
- `lib/core/config/locked_core_config.dart`

## 登录与会话

登录接口：

```text
POST /api/v1/passport/auth/login
```

客户端期望后端返回：

- `authData` / `auth_data`：用于后续 API 的 Authorization。
- `subscribe_url`：用户订阅地址。
- 用户邮箱/手机号等基础信息。

客户端行为：

1. 保存 authData。
2. 保存订阅地址到本地安全/应用存储。
3. 登录成功后自动拉取用户信息和订阅节点。
4. 节点同步失败但本地有缓存时，优先保留缓存供界面展示。

## 注册

注册接口：

```text
POST /api/v1/passport/auth/register
```

当前注册页提交：

- email
- password
- invite_code（可选）

注册页面已隐藏邮箱验证码输入。如后端重新强制注册验证码，需要同步恢复 UI、校验、接口参数和错误提示。

## 忘记密码

忘记密码接口：

```text
POST /api/v1/passport/auth/forget
```

客户端支持邮箱或手机号获取验证码：

- 邮箱：发送邮箱验证码。
- 手机：发送手机验证码。

验证码服务需与后端实现保持一致；短信通道配置在后端处理，客户端不保存短信平台密钥。

## 用户信息与会员状态

用户信息接口由 `UserSubscriptionService` 拉取。客户端根据返回数据计算：

- 是否普通用户。
- 会员是否生效。
- 会员是否到期。
- 流量是否耗尽。
- 是否允许连接。
- 最大设备数、在线设备数。
- 套餐显示名称。

连接前会刷新会员状态。若返回过期、普通用户、流量耗尽或后端拒绝，则阻止连接。

## 订阅与节点

客户端使用 XBoard 订阅地址导入节点，但普通 UI 不展示订阅地址。节点同步流程：

1. 登录或刷新用户信息后拿到订阅地址。
2. 拉取订阅内容。
3. 解析节点。
4. 写入本地 profile/node cache。
5. 当前节点选择保持或自动选择可用节点。

## 版本更新

版本检查地址：

```text
GET /api/app/v1/client-version
```

相关常量：

- `Constants.clientVersionUrl`
- `Constants.githubReleasesApiUrl`
- `Constants.githubLatestReleaseUrl`
- `Constants.appCastUrl`

后台版本号需要与客户端 `pubspec.yaml` 的版本策略统一，否则可能出现后台设置了新版本但客户端不提示升级。

## 规则集

规则集下载地址由：

```dart
lib/core/config/locked_core_config.dart
```

控制。规则集通常随核心配置生成阶段注入，普通用户不可编辑规则集 URL、DNS、fake-ip、IPv6 等底层选项。

## 日志脱敏

禁止输出：

- 完整 authData/token。
- 完整 subscribe_url。
- 节点密码。
- 完整服务器地址。
- 用户浏览域名和内容。

诊断日志只能输出脱敏后的状态、数量、耗时、节点显示名和错误摘要。
