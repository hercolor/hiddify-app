# BflyVPN 客户端 - UI/UX 设计与技术落地方案 (Flutter 浅色版)

## A & C. UI 设计规范与视觉呈现

### 1. 主题与样式规范 (Design System)
*   **整体风格 (Vibe)**：Clean & Trustworthy (清新现代极简风) + Light Mode (浅色模式为主)。采用纯白与淡灰蓝作为底色，搭配清新的科技蓝/天空蓝作为交互强调色，营造“安全、透明、流畅、值得信赖”的视觉感受，更符合现代网络安全工具的调性。
*   **色彩系统 (Color Palette)**：
    *   **主背景色 (Background)**：`#F5F7FA` (极淡的灰蓝色，柔和护眼，提升高级感)
    *   **卡片/浮层底色 (Surface)**：`#FFFFFF` (纯白，用于区分层级，带轻微投影)
    *   **品牌/强调色 (Primary/Accent)**：`#007AFF` (经典信任蓝) 或 `#0EB8FF` (明快天空蓝，用于已连接状态、主按钮)
    *   **未连接/中性状态色 (Disconnected)**：`#B0BEC5` (冷灰) 或 `#E5E7EB` (按钮底色)
    *   **警示色 (Alert)**：`#FF3B30` (柔和红)
    *   **会员/尊贵色 (VIP)**：`#FFB300` (向日葵金) 或 `#7B61FF` (优雅紫)
    *   **文字颜色 (Text)**：`#111827` (主标题，深灰黑)，`#6B7280` (副标题/说明文字)
*   **字体排版 (Typography)**：
    *   英文/数字：`Inter` 或 `SF Pro Display`。
    *   中文：`PingFang SC` (Apple) 或 `Noto Sans SC` (Android/Windows)。
*   **圆角与阴影 (Geometry & Elevation)**：
    *   **全局圆角**：卡片 `16px` 到 `20px`，主按钮 `圆形 (50%)`，小按钮 `12px`。
    *   **阴影 (Shadows)**：轻盈、弥散的阴影。例如连接状态下的卡片阴影：`0 8px 32px rgba(0, 122, 255, 0.15)`；未连接时：`0 4px 16px rgba(0, 0, 0, 0.05)`。

### 2. 高保真 UI 设计蓝图 (页面拆解)
所有页面采用**固定比例布局**（桌面端采用类似 QQ 主界面的 400px * 700px 黄金垂直比例，拒绝大量留白）。

*   **登录页 (Login)**
    *   **视觉**：居中清新的 **BflyVPN** 蓝色 Logo。
    *   **布局**：大圆角纯白输入框层（账号/密码），带微小阴影。底部全宽主蓝色圆角登录按钮，文字为纯白。
*   **首页 - 未连接 (Home - Disconnected)**
    *   **顶部**：左侧深色 BflyVPN Logo，右侧当前网络状态小图标（灰色）。
    *   **中区 (绝对居中)**：巨大的圆形按钮，纯白底色带灰色微阴影，中心图标为“盾牌”或“纸飞机”，颜色为灰色 `#B0BEC5`，文字提示“点击连接”。
    *   **下区**：纯白悬浮卡片显示当前选中节点（如“香港 01”），右侧带浅灰色小箭头可展开节点列表。
    *   **底栏**：固定底部导航（首页、节点、会员），未选中灰色，选中为主题蓝。
*   **首页 - 已连接 (Home - Connected)**
    *   **中区**：大按钮平滑过渡为 `#007AFF` 蓝色渐变，散发淡蓝色弥散阴影。中心图标变为白色，下方显示连接时长（如 `00:15:32`），文字颜色为品牌蓝。
    *   **微动画**：背景出现淡蓝色水波纹或柔和的同心圆扩散 Lottie 动画，象征安全连接正在保护设备。
*   **节点页 (Nodes)**
    *   **布局**：顶部搜索框（纯白底色，淡灰描边）。下方为列表，背景为 `#F5F7FA`。
    *   **卡片设计 (极简)**：纯白卡片，左侧国旗 Emoji + 深灰色节点名称（如“🇸🇬 新加坡 专线 01”），右侧仅显示延迟数字（如 `32ms`）。
    *   **延迟色彩映射**：<50ms (绿色 `#34C759`)，50-150ms (橙色 `#FF9500`)，>150ms (红色 `#FF3B30`)。绝不出现 IP、端口、协议等字符。
*   **会员页 (Profile)**
    *   **顶部卡片**：纯白底色，带金色或淡紫色微光背景，显示用户昵称、套餐名称（如“蝴蝶年卡”）、到期时间。
    *   **数据大屏**：淡蓝色环形进度条显示流量（“已用 120GB / 剩余 880GB”），以及设备数。
    *   **功能列表**：纯白列表项（联系客服、隐私政策、用户协议），最底部为浅红色的“退出登录”按钮。

### 3. Logo、App Icon 与图标集规范
*   **Logo & App Icon**：以 **蝴蝶** 意象为核心，结合“盾牌/云安全”的几何图形。背景为纯白或浅蓝色，数字采用清新的渐变蓝。
*   **图标集 (Iconography)**：圆润线型图标，统一 `2px` 线条宽度。
    *   `ic_home`：极简主页/安全盾牌。
    *   `ic_node`：服务器列表/星球。
    *   `ic_vip`：皇冠/会员卡。

---

## B. 跨平台可落地方案 (基于 Flutter)

为保证 UI 在 iOS/Android/Windows/macOS 高度一致且渲染性能优异，本项目采用 **Flutter** 作为唯一 UI 框架。

### 4. 页面布局落地映射与约束 (Flutter 实现)

*   **根布局 (避免空白)**：
    *   使用 `Scaffold`，设置 `backgroundColor: const Color(0xFFF5F7FA)`。
    *   使用 `BottomNavigationBar` 或自定义底部导航栏。
*   **首页居中按钮**：
    *   使用 `Column` 配合 `Expanded` 或 `Spacer` 将连接大按钮（`GestureDetector` + `Container` + `BoxShadow`）强行挤至垂直居中。
*   **动画实现**：
    *   大按钮的状态切换使用 `AnimatedContainer` 实现颜色、大小、阴影的平滑过渡。
    *   波纹特效使用 `CustomPaint` 或引入 `lottie` 包。
*   **Windows 桌面端特定约束**：
    *   使用 `bitsdojo_window` 或 `window_manager` 插件控制窗口。
    *   强制窗口尺寸：`minSize = Size(380, 680)`, `maxSize = Size(420, 720)`。
    *   自定义 `TitleBar` 融入界面，隐藏系统原生标题栏。

### 5. 核心逻辑与状态机 (State Management)

**性能优化与状态管理：**
1.  **状态管理**：推荐使用 `Riverpod` 或 `Provider` 来管理全局的 VPN 连接状态（Disconnected, Connecting, Connected）。
2.  **长列表优化**：节点列表严格使用 `ListView.builder`，确保复用。
3.  **异步通信**：UI 层与底层 VPN Core (如 sing-box) 通过 `MethodChannel` 或 FFI 通信，测速操作在 Dart `Isolate` 中进行。

**VPN 连接状态机 (幂等性)：**
```dart
enum VpnState { disconnected, connecting, connected, disconnecting }

class VpnNotifier extends StateNotifier<VpnState> {
  VpnNotifier() : super(VpnState.disconnected);

  Future<void> toggleConnection() async {
    if (state == VpnState.connecting || state == VpnState.disconnecting) return;
    
    if (state == VpnState.disconnected) {
      state = VpnState.connecting;
      // 调用底层连接逻辑...
      await Future.delayed(Duration(seconds: 1)); // 模拟连接耗时
      state = VpnState.connected;
    } else {
      state = VpnState.disconnecting;
      // 调用底层断开逻辑...
      await Future.delayed(Duration(seconds: 1)); 
      state = VpnState.disconnected;
    }
  }
}
```

### 6. 最终验收标准清单 (Checklist)

1.  **流畅度验收**：Flutter 产物需在 Profile 模式下验证，列表滚动与动画过渡不掉帧 (60fps/120fps)。
2.  **视觉验收**：严格遵循浅色主题规范，阴影必须柔和（高斯模糊大、透明度低），不可出现生硬的纯黑阴影。
3.  **安全感传达**：连接成功时的蓝色反馈、波纹动画需即时且平滑，让用户产生“已受到保护”的安全心理暗示。
4.  **跨端一致性**：Windows 端必须支持最小化到托盘（Tray），右键菜单响应迅速；移动端状态栏沉浸式处理，颜色与背景融为一体。
5.  **节点隐私验收**：绝不泄露 IP、端口等配置细节，界面仅呈现“极简傻瓜式”的用户体验。
