import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/core/widget/desktop/desktop_window_chrome.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/customer_service_uri.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PremiumRenewalPage extends ConsumerWidget {
  const PremiumRenewalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authNotifierProvider).valueOrNull?.session;
    final subscription = session?.subscription;
    return _PremiumScaffold(
      title: '会员续费',
      child: session == null
          ? const _LoginRequiredPanel()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        '选择您的订阅方案',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const Gap(8),
                      const Text('解锁高速专线与稳定连接体验', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                      const Gap(26),
                      _CurrentPlanCard(session: session, subscription: subscription),
                      const Gap(16),
                      const _PlanOptionCard(selected: false, title: '月度套餐', description: '适合短期使用，灵活续费', tag: '灵活'),
                      const Gap(16),
                      const _PlanOptionCard(selected: true, title: '年度套餐', description: '长期使用更划算，优先推荐', tag: '推荐'),
                      const Gap(16),
                      const _PlanOptionCard(selected: false, title: '企业套餐', description: '多设备与商务支持方案', tag: '商务'),
                    ],
                  ),
                ),
                _BottomAction(
                  label: '联系客服续费',
                  onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
                ),
              ],
            ),
    );
  }
}

class PremiumInvitePage extends ConsumerWidget {
  const PremiumInvitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authNotifierProvider).valueOrNull?.session;
    return _PremiumScaffold(
      title: '邀请有礼',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_giftcard_rounded, size: 80, color: Color(0xFFFF9500)),
              const Gap(24),
              const Text(
                '邀请好友，共享极速',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const Gap(8),
              Text(
                session == null ? '登录后可查看您的邀请权益。' : '邀请权益请以客服确认的活动规则为准。',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const Gap(36),
              const _SoftInfoBox(
                icon: Icons.verified_user_rounded,
                title: '安全提示',
                subtitle: '邀请链接和活动规则不会展示订阅链接或节点敏感信息。',
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _openCustomerService(context, ref, session?.subscription?.customerService),
                  style: _primaryButtonStyle(),
                  child: const Text('联系客服了解活动', style: _buttonTextStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumFeedbackPage extends ConsumerStatefulWidget {
  const PremiumFeedbackPage({super.key});

  @override
  ConsumerState<PremiumFeedbackPage> createState() => _PremiumFeedbackPageState();
}

class _PremiumFeedbackPageState extends ConsumerState<PremiumFeedbackPage> {
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(inAppNotificationControllerProvider).showInfoToast('感谢您的反馈');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumScaffold(
      title: '反馈问题',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _FieldLabel('问题描述'),
          const Gap(8),
          _InputCard(
            child: TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '请详细描述您遇到的问题或建议...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const Gap(24),
          const _FieldLabel('联系方式（选填）'),
          const Gap(8),
          _InputCard(
            child: TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                hintText: '留下您的邮箱或联系方式，方便我们联系您',
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const Gap(32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submit,
              style: _primaryButtonStyle(),
              child: const Text('提交反馈', style: _buttonTextStyle),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumWebsitePage extends ConsumerWidget {
  const PremiumWebsitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authNotifierProvider).valueOrNull?.session;
    return _PremiumScaffold(
      title: '官网链接',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 80, color: Color(0xFF10B981)),
              const Gap(24),
              const Text(
                '访问 4376 官方支持',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const Gap(8),
              const Text(
                '获取最新客户端、使用帮助及服务支持。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const Gap(36),
              const _SoftInfoBox(icon: Icons.public_rounded, title: '4376', subtitle: '官方入口以客服返回的信息为准'),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _openCustomerService(context, ref, session?.subscription?.customerService),
                  style: _primaryButtonStyle(),
                  child: const Text('打开官方支持', style: _buttonTextStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumPreferencesPage extends ConsumerWidget {
  const PremiumPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobalMode = ref.watch(ConfigOptions.globalRouteMode);
    return _PremiumScaffold(
      title: '高级设置',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _FieldLabel('网络与连接'),
          const Gap(8),
          _InputCard(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: const Text(
                '全局代理模式',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                isGlobalMode ? '所有流量将通过 4376 传输' : '智能分流，仅代理必要流量',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              activeThumbColor: const Color(0xFF2563EB),
              value: isGlobalMode,
              onChanged: (value) => ref.read(ConfigOptions.globalRouteMode.notifier).update(value),
              secondary: Icon(
                isGlobalMode ? Icons.public_rounded : Icons.alt_route_rounded,
                color: isGlobalMode ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const Gap(24),
          const _FieldLabel('应用与系统'),
          const Gap(8),
          const _SoftInfoBox(icon: Icons.info_outline_rounded, title: '说明', subtitle: '普通用户仅开放全局/智能路由切换；技术配置保留在隐藏诊断中。'),
        ],
      ),
    );
  }
}

class _PremiumScaffold extends StatelessWidget {
  const _PremiumScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const _PremiumBackButton(),
        title: Text(title),
        centerTitle: false,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w600),
      ),
      body: child,
    );
    if (!PlatformUtils.isWindows) return scaffold;
    return DesktopTheme(
      child: DesktopWindowChrome(backgroundColor: const Color(0xFFF8FAFC), child: scaffold),
    );
  }
}

class _PremiumBackButton extends StatelessWidget {
  const _PremiumBackButton();

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isWindows) return const DesktopBackButton();
    return IconButton(
      tooltip: '返回',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed('home');
        }
      },
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
    );
  }
}

class _LoginRequiredPanel extends StatelessWidget {
  const _LoginRequiredPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline_rounded, size: 72, color: Color(0xFF2563EB)),
            const Gap(18),
            const Text(
              '请先登录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const Gap(8),
            const Text('登录后可查看会员权益与续费入口', style: TextStyle(color: Color(0xFF64748B))),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => context.goNamed('settings'),
                style: _primaryButtonStyle(),
                child: const Text('去登录', style: _buttonTextStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.session, required this.subscription});

  final AuthSession session;
  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2D3E), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(.22), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.10), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700)),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayText(subscription?.planName, fallback: '4376 Pro'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const Gap(4),
                Text('账号 ${_maskUser(session.email)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({required this.selected, required this.title, required this.description, required this.tag});

  final bool selected;
  final String title;
  final String description;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2563EB).withOpacity(.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: 2),
        boxShadow: selected ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(.10), blurRadius: 10)] : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)])
                            : null,
                        color: selected ? null : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF5C4000), fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text(
            '咨询',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: selected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onPressed,
            style: _primaryButtonStyle(),
            child: Text(label, style: _buttonTextStyle),
          ),
        ),
      ),
    );
  }
}

class _SoftInfoBox extends StatelessWidget {
  const _SoftInfoBox({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const Gap(4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF2563EB),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 0,
  );
}

const _buttonTextStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white);

String _displayText(String? value, {String fallback = '--'}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return fallback;
  return trimmed;
}

String _maskUser(String value) {
  final trimmed = value.trim();
  if (!trimmed.contains('@')) return trimmed.length <= 2 ? '***' : '${trimmed.substring(0, 1)}***';
  final parts = trimmed.split('@');
  return '${parts.first.substring(0, 1)}***@${parts.last}';
}

Future<void> _openCustomerService(BuildContext context, WidgetRef ref, String? customerService) async {
  final notification = ref.read(inAppNotificationControllerProvider);
  final uri = customerServiceUri(customerService);
  if (uri == null) {
    notification.showInfoToast('客服暂未配置');
    return;
  }
  final launched = await UriUtils.tryLaunch(uri);
  if (!launched) notification.showErrorToast('无法打开客服，请稍后重试');
}
