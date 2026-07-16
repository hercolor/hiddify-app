# BflyVPN 新包名与自定义 Scheme 规范

**文档状态：** 前后端 / 三端客户端对接规范
**关联：** `docs/product-definition-v0.1.md`
**日期：** 2026-07-16
**原则：** 新安装身份；支付走系统浏览器；用 scheme 唤回 App 并自动刷新会员。

---

## 1. 目标

| 目标 | 说明 |
|------|------|
| 新包名 | 接受全新 applicationId / Bundle ID，**不要求**覆盖旧安装升级 |
| 自定义 Scheme | 浏览器支付完成（及取消/失败）后可靠唤起 BflyVPN |
| 自动刷新 | 回 App 后自动查询订单/会员，无需用户主路径点「我已支付」 |
| 安全 | scheme 载荷不可携带完整密钥与订阅 URL |
| 三端一致 | Android / Windows / iOS 使用 **同一 scheme 名与同一 path 语义** |

---

## 2. 应用身份（包名 / Bundle）

### 2.1 产品要求

- 对外显示名：**BflyVPN**
- 安装身份：**新包名**（与历史 `pro.y88.accelerator` / 旧 iOS id 脱钩）
- 旧包与新包可并存；不承诺数据自动迁移（若做迁移另立需求）

### 2.2 推荐标识（待最终确认后锁定）

下列为 **推荐默认值**。上线前必须由负责人在表格「最终值」列签字锁定；锁定前实现可用 feature flag / 配置，但不可三端各写各的。

| 平台 | 字段 | 推荐值 | 最终值（锁定） |
|------|------|--------|----------------|
| Android | `applicationId` | `pro.y88.bflyvpn` | _待填_ |
| Android | 显示名 | BflyVPN | BflyVPN |
| iOS | 主 App Bundle ID | `pro.y88.bflyvpn` | _待填_ |
| iOS | Packet Tunnel Extension | `pro.y88.bflyvpn.PacketTunnel` | _待填_ |
| Windows | 产品名 / 快捷方式 | BflyVPN | BflyVPN |
| Windows | 可执行文件 | `BflyVPN.exe` | BflyVPN.exe |
| Windows | 安装目录/AUMID 相关 | 与 BflyVPN 一致，避免 Hiddify | _待填_ |

**命名约束：**

- 全小写反向域名风格；仅 `[a-z0-9.]`
- Extension Bundle 必须挂在主 App 前缀下
- 一旦商店提交，**禁止静默再改** applicationId / Bundle ID

### 2.3 与旧包关系

| 项 | 策略 |
|----|------|
| 旧 Android `pro.y88.accelerator` | 视为遗留；新包独立 |
| 旧 iOS `pro.y88.hudiejiasu` | 视为遗留；新包独立 |
| 用户数据 | 默认不迁移；登录后云端会话/订阅仍由账号体系恢复节点 |
| 商店 | 新包按新应用上架；旧包下架策略另定 |

---

## 3. URL Scheme

### 3.1 主 Scheme

| 项 | 值 |
|----|-----|
| Scheme | `bflyvpn` |
| 形式 | `bflyvpn://<host>/<path>?<query>` |
| 大小写 | scheme 小写；host/path 小写 |
| 备用 | 首发不做多 scheme；若系统冲突再评估 |

**示例：**

```text
bflyvpn://pay/result?order_id=ORDER123&status=success
bflyvpn://pay/result?order_id=ORDER123&status=cancel
bflyvpn://pay/result?order_id=ORDER123&status=fail
bflyvpn://app/refresh
```

### 3.2 Host / Path 约定

| host | path | 用途 | 客户端行为 |
|------|------|------|------------|
| `pay` | `/result` | 支付结果回跳 | 解析 query → 自动查单/刷会员 → 更新 UI |
| `app` | `/refresh` | 通用刷新（可选） | 仅刷新会员与节点门禁相关状态 |
| 其他 | — | 未识别 | 打开 App 到连接或我的；可打点 `unknown_deep_link` |

### 3.3 Query 参数

#### 支付结果 `bflyvpn://pay/result`

| 参数 | 必填 | 说明 | 约束 |
|------|------|------|------|
| `order_id` | 是 | 订单号 | 与后端创建订单返回一致；URL 编码 |
| `status` | 建议 | `success` / `cancel` / `fail` / `unknown` | 仅作 UI 提示；**以服务端查单为准** |
| `token` | 否 | 短时一次性校验码 | 若后端提供，用于防篡改；**不是** authData |
| `ts` | 否 | 时间戳 | 可选防重放辅助 |

**禁止出现在 query 中：**

- `authData` / `token`（登录令牌）/ 密码
- `subscribe_url` / 订阅 token 明文
- 节点地址、密码、完整配置

#### 通用刷新 `bflyvpn://app/refresh`

| 参数 | 必填 | 说明 |
|------|------|------|
| `reason` | 否 | 如 `pay` / `manual`；仅分析用 |

### 3.4 解析优先级

1. 合法 scheme + 已知 host/path → 走对应处理器
2. `status` 与服务端订单状态冲突 → **以服务端为准**，UI 可提示「已为你同步最新状态」
3. 无 `order_id` 的 pay/result → 仍触发一次会员刷新，并提示结果未知
4. 重复打开同一 `order_id` → 幂等：不重复弹成功，可静默刷新

---

## 4. 支付闭环时序

### 4.1 主路径

```
App 套餐页
  → POST 创建订单（Authorization: authData）
  → 后端返回 order_id + pay_url（HTTPS）
  → App 调起系统浏览器打开 pay_url
  → 用户支付
  → 支付完成页 302/跳转到 bflyvpn://pay/result?...
  → OS 唤起 BflyVPN
  → App：展示「确认中」→ 查询订单状态 + 拉取用户信息
  → 成功：更新到期时间/设备权益 → 可连接
  → 失败/取消：明确文案 + 可重新支付
```

### 4.2 兜底路径（必须实现）

| 场景 | 行为 |
|------|------|
| 用户支付成功但未点回跳 | App **回到前台（onResume）** 时：若存在「进行中订单」，自动查单 + 刷会员 |
| 回跳失败 / 浏览器未唤起 | 套餐页提供弱按钮「刷新支付状态」 |
| 查单处理中 | 按钮防抖；避免并发打爆 API |
| 长时间 unknown | 提示稍后在「我的」下拉刷新或联系客服 |

### 4.3 状态机（客户端支付会话）

| 状态 | 含义 | UI |
|------|------|-----|
| `idle` | 无进行中支付 | 正常套餐列表 |
| `awaiting_browser` | 已打开浏览器 | 「请在浏览器完成支付」 |
| `confirming` | 已回 App / 回前台，查单中 | 「正在确认支付结果」 |
| `paid` | 订单已支付且会员已刷新 | 成功 → 可去连接 |
| `failed` | 明确失败 | 失败原因 + 重试 |
| `cancelled` | 用户取消 | 可重新选择套餐 |
| `unknown` | 超时仍不确定 | 刷新 + 客服 |

---

## 5. 后端契约（最小集）

### 5.1 创建订单（示意）

```http
POST /api/v1/.../order  (最终路径以后端为准)
Authorization: <authData>
Content-Type: application/json

{
  "plan_id": 123,
  "period": "month"
}
```

**响应至少包含：**

| 字段 | 说明 |
|------|------|
| `order_id` | 订单号 |
| `pay_url` | 系统浏览器打开的 HTTPS 地址 |
| `expire_at` | 可选，订单过期时间 |

`pay_url` 对应的 **支付完成页** 必须支持跳转：

```text
bflyvpn://pay/result?order_id={order_id}&status=success
```

取消/失败页建议：

```text
bflyvpn://pay/result?order_id={order_id}&status=cancel
bflyvpn://pay/result?order_id={order_id}&status=fail
```

### 5.2 查询订单（示意）

```http
GET /api/v1/.../order/{order_id}
Authorization: <authData>
```

**响应至少包含：**

| 字段 | 说明 |
|------|------|
| `order_id` | 订单号 |
| `status` | `pending` / `paid` / `failed` / `cancelled` / `expired` |
| `plan_id` | 可选 |
| `paid_at` | 可选 |

### 5.3 用户信息（支付成功后必刷）

沿用/扩展现有用户信息接口，客户端需要：

| 字段意图 | 用途 |
|----------|------|
| 到期时间 | 门禁与展示 |
| 设备上限 / 当前设备数 | 门禁与展示 |
| 是否可连接 | 以后端为准时可覆盖本地推断 |
| 套餐展示名 | 我的页 |
| **不依赖流量拒绝连接** | 与产品 v0.1 一致 |

### 5.4 安全建议（后端）

- `pay_url` 仅 HTTPS
- 完成页跳转 scheme 时不要拼接用户敏感信息
- 可选：`token` 短时签名，客户端回传查单接口校验
- 订单状态以服务端为准；scheme 的 `status` 仅 UX

---

## 6. 三端实现要点

### 6.1 Android

| 项 | 要求 |
|----|------|
| `applicationId` | 使用锁定新包名 |
| Intent Filter | `bflyvpn` scheme；`pay/result` 与可选 `app/refresh` |
| 导出 | 仅必要 Activity 处理 deep link；防错 Intent |
| 浏览器 | `ACTION_VIEW` 打开 `pay_url`（系统浏览器或用户默认浏览器） |
| 回前台 | `onResume` 检查进行中订单并查单 |
| 显示名 | BflyVPN |

### 6.2 iOS

| 项 | 要求 |
|----|------|
| Bundle ID | 主 App + PacketTunnel 新 id |
| URL Types | 注册 `bflyvpn` |
| 打开支付 | `UIApplication.open` 打开 HTTPS `pay_url` |
| 回前台 | `scenePhase` / `applicationDidBecomeActive` 查单 |
| 扩展 | Extension **不**处理支付 scheme；仅主 App |
| 审核 | 隐私与 VPN 用途说明与正式产品一致；支付若仅跳转网页需符合指南 |

### 6.3 Windows

| 项 | 要求 |
|----|------|
| 协议注册 | 安装包注册 `bflyvpn` URL Protocol（HKCR 或安装器配置） |
| 便携包 | 文档说明：便携版需注册协议或提供「复制支付链接 + 手动刷新」降级 |
| 打开浏览器 | 系统默认浏览器打开 `pay_url` |
| 单实例 | 协议唤起时应激活已有窗口，避免多开丢状态 |
| 回前台 | 窗口激活时若有进行中订单则查单 |

**Windows 安装包为支付主路径；便携包若无法注册协议，必须实现「回前台/手动刷新」兜底，并在 UI 说明。**

---

## 7. 与连接门禁的衔接

支付成功刷新会员后：

1. 更新本地 session 中的到期时间、设备信息、`can_connect`
2. 若用户在连接页：门禁从不可连变为可连，**不必自动连接**（避免静默起 VPN）；可展示「会员已生效，可以连接」
3. 设备仍超限：即使支付成功，仍按设备门禁拦截并提示（支付买的是时长/权益，不自动解决占满设备）

---

## 8. 日志与隐私

| 允许 | 禁止 |
|------|------|
| order_id 摘要、status、耗时 | 完整 authData |
| scheme host/path、是否成功解析 | subscribe_url 全文 |
| 查单 HTTP 状态码 | 支付渠道敏感回跳整串若含 PII |

---

## 9. 测试清单

### 9.1 身份

| ID | 用例 | 期望 |
|----|------|------|
| P-01 | 新包名安装 | 显示 BflyVPN；与旧包可并存 |
| P-02 | iOS 主 App + 扩展 id | 扩展可加载；签名匹配 |
| P-03 | Windows 安装后协议 | `bflyvpn://` 可唤起 |

### 9.2 Scheme 与支付

| ID | 用例 | 期望 |
|----|------|------|
| P-10 | 创建订单拿到 pay_url | 浏览器打开成功 |
| P-11 | 成功回跳 | App 打开；confirming → paid；会员到期更新 |
| P-12 | 取消回跳 | cancelled；可重试 |
| P-13 | 失败回跳 | failed；可重试 |
| P-14 | 无回跳仅回前台 | 进行中订单自动查单 |
| P-15 | 重复回跳同一 order | 幂等，不重复脏状态 |
| P-16 | 恶意 query 带假 success | 以服务端查单为准，不误开通 |
| P-17 | scheme 含禁止字段 | 忽略敏感参数；不落日志 |
| P-18 | 未登录时被 scheme 唤起 | 进登录；登录后可再刷新订单（策略可定为丢弃订单会话） |

### 9.3 三端同日

Android / Windows / iOS 均需通过 P-10–P-16（Windows 便携可标降级项）。

---

## 10. 上线前锁定检查表

- [ ] applicationId / Bundle ID 最终值已填并三端一致策略确认
- [ ] `bflyvpn` 在三端注册完成
- [ ] 后端支付完成页跳转 URL 已配置
- [ ] 查单接口与会员刷新联调通过
- [ ] 安全评审：scheme 无敏感参数
- [ ] 测试清单 P-01–P-17 通过
- [ ] 产品文案：成功/失败/确认中/设备仍超限

---

## 11. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-07-16 | 首版：新包名、scheme、支付时序、后端契约、三端与测试 |
