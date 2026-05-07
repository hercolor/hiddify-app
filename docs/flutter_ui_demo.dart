import 'package:flutter/material.dart';

void main() {
  runApp(const VpnAppDemo());
}

class VpnAppDemo extends StatelessWidget {
  const VpnAppDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '4376 VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // 淡灰蓝色背景
        primaryColor: const Color(0xFF007AFF), // 品牌蓝
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FA),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF111827)),
          titleTextStyle: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 1. 登录页 (Login Screen)
// ==========================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(child: Icon(Icons.shield_rounded, size: 48, color: Color(0xFF007AFF))),
              ),
              const SizedBox(height: 24),
              const Text(
                '4376',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF007AFF), letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              const Text('安全、极速、无界', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 48),

              _buildTextField(icon: Icons.email_outlined, hint: '邮箱账号'),
              const SizedBox(height: 16),
              _buildTextField(icon: Icons.lock_outline, hint: '密码', obscure: true),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    '登 录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              const Text('遇到问题？联系客服', style: TextStyle(color: Color(0xFF007AFF), fontSize: 14)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required IconData icon, required String hint, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
          prefixIcon: Icon(icon, color: const Color(0xFFB0BEC5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

// ==========================================
// 2. 主页面框架 (带底部导航)
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [const HomeTab(), const NodesTab(), const ProfileTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 10,
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: const Color(0xFFB0BEC5),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shield_rounded), label: '连接'),
          BottomNavigationBarItem(icon: Icon(Icons.language_rounded), label: '节点'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: '我的'),
        ],
      ),
    );
  }
}

// ==========================================
// 3. 首页 (Home Tab)
// ==========================================
enum VpnState { disconnected, connecting, connected }

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  VpnState _vpnState = VpnState.disconnected;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_vpnState == VpnState.connecting) return;
    if (_vpnState == VpnState.disconnected) {
      setState(() => _vpnState = VpnState.connecting);
      _pulseController.repeat(reverse: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _vpnState = VpnState.connected);
        _pulseController.stop();
        _pulseController.reset();
      }
    } else {
      setState(() => _vpnState = VpnState.disconnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _vpnState == VpnState.connected;
    final isConnecting = _vpnState == VpnState.connecting;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '4376',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                ),
                Icon(Icons.security, color: isConnected ? const Color(0xFF007AFF) : const Color(0xFFB0BEC5)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isConnected ? '已受保护' : (isConnecting ? '连接中...' : '尚未连接'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isConnected ? const Color(0xFF007AFF) : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected ? '00:15:32' : '点击按钮以保护您的隐私',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 64),
                  GestureDetector(
                    onTap: _toggleConnection,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isConnecting ? _pulseAnimation.value : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? const Color(0xFF007AFF) : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: isConnected
                                      ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: isConnected ? 40 : 20,
                                  spreadRadius: isConnected ? 10 : 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isConnected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                                size: 80,
                                color: isConnected ? Colors.white : const Color(0xFFB0BEC5),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                    child: const Text('🇸🇬', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '新加坡 专线 01',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                        SizedBox(height: 4),
                        Text('智能路由推荐', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '32ms',
                      style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 节点列表页 (Nodes Tab)
// ==========================================
class NodesTab extends StatelessWidget {
  const NodesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final nodes = [
      {'flag': '🇸🇬', 'name': '新加坡 专线 01', 'ping': 32},
      {'flag': '🇭🇰', 'name': '香港 游戏专线', 'ping': 45},
      {'flag': '🇯🇵', 'name': '日本 东京 03', 'ping': 85},
      {'flag': '🇺🇸', 'name': '美国 洛杉矶 01', 'ping': 165},
      {'flag': '🇬🇧', 'name': '英国 伦敦 01', 'ping': 210},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('选择节点'), centerTitle: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: '搜索国家或地区...',
                  hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFB0BEC5)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                final ping = node['ping']! as int;
                final Color pingColor = ping < 50
                    ? const Color(0xFF34C759)
                    : (ping < 150 ? const Color(0xFFFF9500) : const Color(0xFFFF3B30));

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(node['flag']! as String, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(
                      node['name']! as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827)),
                    ),
                    trailing: Text(
                      '${ping}ms',
                      style: TextStyle(color: pingColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onTap: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. 个人中心页 (Profile Tab)
// ==========================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isGlobalMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的账号'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        children: [
          // 会员卡片
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A2D3E), Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CyberNinja',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text('ID: 88437621', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium, size: 16, color: Color(0xFF5C4000)),
                          SizedBox(width: 4),
                          Text(
                            '4376 Pro',
                            style: TextStyle(color: Color(0xFF5C4000), fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('到期时间', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          '2027-01-01',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RenewalScreen()));
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        '立即续费',
                        style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 路由设置
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              '路由设置',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: const Text(
                '全局代理模式',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)),
              ),
              subtitle: Text(
                _isGlobalMode ? '所有流量将通过 VPN 传输' : '智能分流，仅代理必要流量',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              activeThumbColor: const Color(0xFF007AFF),
              value: _isGlobalMode,
              onChanged: (bool value) => setState(() => _isGlobalMode = value),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isGlobalMode ? const Color(0xFF007AFF).withValues(alpha: 0.1) : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.public, color: _isGlobalMode ? const Color(0xFF007AFF) : const Color(0xFFB0BEC5)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 其他功能
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              '其他功能',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.card_giftcard_rounded,
                  title: '邀请有礼',
                  subtitle: '邀请好友得免费时长',
                  iconColor: const Color(0xFFFF9500),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen())),
                ),
                const Divider(height: 1, indent: 56, endIndent: 24, color: Color(0xFFF5F7FA)),
                _buildListTile(
                  icon: Icons.feedback_outlined,
                  title: '反馈问题',
                  iconColor: const Color(0xFF007AFF),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                ),
                const Divider(height: 1, indent: 56, endIndent: 24, color: Color(0xFFF5F7FA)),
                _buildListTile(
                  icon: Icons.language_rounded,
                  title: '官网链接',
                  iconColor: const Color(0xFF34C759),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebsiteScreen())),
                ),
                const Divider(height: 1, indent: 56, endIndent: 24, color: Color(0xFFF5F7FA)),
                _buildListTile(
                  icon: Icons.settings_outlined,
                  title: '高级设置',
                  iconColor: const Color(0xFF6B7280),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              '退出登录',
              style: TextStyle(color: Color(0xFFFF3B30), fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827)),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BEC5)),
      onTap: onTap,
    );
  }
}

// ==========================================
// 6. 续费中心 (Renewal Screen)
// ==========================================
class RenewalScreen extends StatefulWidget {
  const RenewalScreen({super.key});

  @override
  State<RenewalScreen> createState() => _RenewalScreenState();
}

class _RenewalScreenState extends State<RenewalScreen> {
  int _selectedPlanIndex = 1; // 默认选中第二个(年度套餐)

  final List<Map<String, dynamic>> _plans = [
    {'title': '1个月', 'price': '¥ 25', 'desc': '标准月付', 'isHot': false},
    {'title': '12个月', 'price': '¥ 198', 'desc': '约 ¥16.5/月', 'isHot': true},
    {'title': '永久', 'price': '¥ 698', 'desc': '一次付费，终身使用', 'isHot': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会员续费')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '选择您的订阅方案',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                const Text('解锁所有高速专线及无限流量', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                const SizedBox(height: 32),

                ...List.generate(_plans.length, (index) {
                  final plan = _plans[index];
                  final isSelected = _selectedPlanIndex == index;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedPlanIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF007AFF).withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: const Color(0xFF007AFF).withValues(alpha: 0.1), blurRadius: 10)]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    plan['title'] as String,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (plan['isHot'] as bool) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '最超值',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF5C4000),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                plan['desc'] as String,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                          Text(
                            plan['price'] as String,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // 底部支付按钮
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('跳转支付...')));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '确认支付',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. 邀请有礼 (Invite Screen)
// ==========================================
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请有礼')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_giftcard_rounded, size: 80, color: Color(0xFFFF9500)),
              const SizedBox(height: 24),
              const Text(
                '邀请好友，共享极速',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                '每成功邀请一位好友，双方各得 30 天 4376 Pro 时长。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'https://4376.net/inv/ABCD12',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF007AFF)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制邀请链接')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '立即分享',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 8. 反馈问题 (Feedback Screen)
// ==========================================
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('反馈问题')),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            '问题描述',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const TextField(
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '请详细描述您遇到的问题或建议...',
                hintStyle: TextStyle(color: Color(0xFFB0BEC5)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '联系方式 (选填)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: '留下您的邮箱或电报，方便我们联系您',
                hintStyle: TextStyle(color: Color(0xFFB0BEC5)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('感谢您的反馈！')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                '提交反馈',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 9. 官网链接 (Website Screen)
// ==========================================
class WebsiteScreen extends StatelessWidget {
  const WebsiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('官网链接')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 80, color: Color(0xFF34C759)),
              const SizedBox(height: 24),
              const Text(
                '访问我们的官方网站',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                '获取最新客户端、查看使用教程及服务条款。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Text(
                  'https://4376.net',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '在浏览器中打开',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 10. 设置中心 (Settings Screen)
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoStart = true;
  bool _killSwitch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('高级设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '网络与连接',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('开机自动启动', style: TextStyle(fontWeight: FontWeight.w500)),
                  activeThumbColor: const Color(0xFF007AFF),
                  value: _autoStart,
                  onChanged: (v) => setState(() => _autoStart = v),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF5F7FA)),
                SwitchListTile(
                  title: const Text('Kill Switch 断网保护', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('VPN意外断开时阻止所有网络流量', style: TextStyle(fontSize: 11)),
                  activeThumbColor: const Color(0xFF007AFF),
                  value: _killSwitch,
                  onChanged: (v) => setState(() => _killSwitch = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            '应用与系统',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('语言设置', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('跟随系统', style: TextStyle(color: Color(0xFF6B7280))),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BEC5)),
                    ],
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF5F7FA)),
                ListTile(
                  title: const Text('清除缓存', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Text('32.4 MB', style: TextStyle(color: Color(0xFF6B7280))),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF5F7FA)),
                ListTile(
                  title: const Text('关于 4376 VPN', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Text('v2.1.0', style: TextStyle(color: Color(0xFF6B7280))),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
