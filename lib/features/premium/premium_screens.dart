import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/customer_service_uri.dart';
import 'package:hiddify/features/premium/data/premium_api_service.dart';
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
                      const Text('选择您的套餐方案', style: BrandDesktopText.sectionTitle),
                      const Gap(6),
                      const Text('解锁高速专线与稳定连接体验', style: BrandDesktopText.bodySecondary),
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

class PremiumInvitePage extends ConsumerStatefulWidget {
  const PremiumInvitePage({super.key});

  @override
  ConsumerState<PremiumInvitePage> createState() => _PremiumInvitePageState();
}

class _PremiumInvitePageState extends ConsumerState<PremiumInvitePage> {
  late Future<PremiumInviteOverview> _inviteFuture;
  late String? _authData;
  bool _creatingCode = false;

  @override
  void initState() {
    super.initState();
    _authData = ref.read(authNotifierProvider).valueOrNull?.session?.authData;
    _inviteFuture = _loadInvite(_authData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAuthData = ref.read(authNotifierProvider).valueOrNull?.session?.authData;
    if (nextAuthData != _authData) {
      _authData = nextAuthData;
      _inviteFuture = _loadInvite(_authData);
    }
  }

  Future<PremiumInviteOverview> _loadInvite(String? authData) async {
    final value = authData?.trim();
    if (value == null || value.isEmpty) throw const AuthFailure.notLoggedIn();
    final service = await ref.read(premiumApiServiceProvider.future);
    return service.fetchInvite(value);
  }

  void _refresh() {
    setState(() => _inviteFuture = _loadInvite(_authData));
  }

  Future<void> _createInviteCode() async {
    final authData = _authData?.trim();
    if (authData == null || authData.isEmpty || _creatingCode) return;
    setState(() => _creatingCode = true);
    try {
      final service = await ref.read(premiumApiServiceProvider.future);
      await service.createInviteCode(authData);
      if (!mounted) return;
      ref.read(inAppNotificationControllerProvider).showSuccessToast('邀请码已生成');
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ref.read(inAppNotificationControllerProvider).showErrorToast(_failureMessage(error, fallback: '邀请码生成失败'));
    } finally {
      if (mounted) setState(() => _creatingCode = false);
    }
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ref.read(inAppNotificationControllerProvider).showSuccessToast('邀请码已复制');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authNotifierProvider).valueOrNull?.session;
    if (session == null) {
      return const _PremiumScaffold(title: '邀请有礼', child: _LoginRequiredPanel());
    }
    if (session.authData != _authData) {
      _authData = session.authData;
      _inviteFuture = _loadInvite(_authData);
    }
    return _PremiumScaffold(
      title: '邀请有礼',
      child: FutureBuilder<PremiumInviteOverview>(
        future: _inviteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return _PremiumErrorPanel(
              message: _failureMessage(snapshot.error, fallback: '邀请信息加载失败'),
              onRetry: _refresh,
            );
          }
          final overview = snapshot.data;
          if (overview == null) {
            return _PremiumErrorPanel(message: '邀请信息为空', onRetry: _refresh);
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const Text('邀请好友，共享权益', style: BrandDesktopText.sectionTitle),
                const Gap(6),
                const Text('邀请返利数据来自后台接口，仅展示活动统计与邀请码。', style: BrandDesktopText.bodySecondary),
                const Gap(22),
                _InviteStatsGrid(stat: overview.stat),
                const Gap(18),
                _InviteCodeSection(
                  codes: overview.codes,
                  creatingCode: _creatingCode,
                  onCreate: _createInviteCode,
                  onCopy: _copyInviteCode,
                ),
                const Gap(18),
                const _SoftInfoBox(
                  icon: Icons.privacy_tip_outlined,
                  title: '安全提示',
                  subtitle: '这里只展示邀请码和佣金统计，不展示订阅链接、节点地址或账号密钥。',
                ),
              ],
            ),
          );
        },
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
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authNotifierProvider).valueOrNull?.session;
    if (session == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast('请先登录账号');
      return;
    }
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ref.read(inAppNotificationControllerProvider).showErrorToast('请填写问题描述');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final service = await ref.read(premiumApiServiceProvider.future);
      await service.createTicket(
        session.authData,
        subject: _ticketSubject(message),
        level: 1,
        message: _ticketMessage(message: message, contact: _contactController.text, email: session.email),
      );
      if (!mounted) return;
      ref.read(inAppNotificationControllerProvider).showSuccessToast('反馈已提交');
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ref.read(inAppNotificationControllerProvider).showErrorToast(_failureMessage(error, fallback: '反馈提交失败'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authNotifierProvider).valueOrNull?.session;
    if (session == null) {
      return const _PremiumScaffold(title: '反馈问题', child: _LoginRequiredPanel());
    }
    return _PremiumScaffold(
      title: '反馈问题',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('提交工单支持', style: BrandDesktopText.sectionTitle),
          const Gap(6),
          const Text('反馈将通过后台工单系统提交，客服会在后台处理。', style: BrandDesktopText.bodySecondary),
          const Gap(24),
          const _FieldLabel('问题描述'),
          const Gap(8),
          _InputCard(
            child: TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '请详细描述您遇到的问题或建议...',
                hintStyle: BrandDesktopText.bodySecondary.copyWith(color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const Gap(24),
          const _FieldLabel('联系方式（选填）'),
          const Gap(8),
          _InputCard(
            child: TextField(
              controller: _contactController,
              decoration: InputDecoration(
                hintText: '留下您的邮箱或联系方式，方便我们联系您',
                hintStyle: BrandDesktopText.bodySecondary.copyWith(color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const Gap(18),
          const _SoftInfoBox(icon: Icons.support_agent_rounded, title: '工单支持', subtitle: '请勿在反馈中填写订阅链接、节点地址或账号密钥。'),
          const Gap(32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: _primaryButtonStyle(),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('提交反馈', style: _buttonTextStyle),
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
              const Icon(Icons.language_rounded, size: 64, color: Color(0xFF10B981)),
              const Gap(18),
              const Text('访问 4376 官方支持', style: BrandDesktopText.sectionTitle),
              const Gap(6),
              const Text('获取最新客户端、使用帮助及服务支持。', textAlign: TextAlign.center, style: BrandDesktopText.bodySecondary),
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

class PremiumContactPage extends ConsumerWidget {
  const PremiumContactPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerService = ref.watch(authNotifierProvider).valueOrNull?.session?.subscription?.customerService;
    final hasCustomerService = customerService?.trim().isNotEmpty == true;
    return _PremiumScaffold(
      title: '联系客服',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent_rounded, size: 64, color: Color(0xFF2563EB)),
              const Gap(18),
              const Text('4376 客服支持', style: BrandDesktopText.sectionTitle),
              const Gap(6),
              Text(
                hasCustomerService ? '如需续费、套餐、节点或账号帮助，请通过客服入口联系。' : '客服入口暂未配置，请稍后重试。',
                textAlign: TextAlign.center,
                style: BrandDesktopText.bodySecondary,
              ),
              const Gap(36),
              _SoftInfoBox(
                icon: Icons.privacy_tip_outlined,
                title: '隐私提示',
                subtitle: hasCustomerService ? '联系客服不会展示订阅链接、节点地址或账号密钥。' : '未获取到客服配置，请确认账号套餐信息已同步。',
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: hasCustomerService ? () => _openCustomerService(context, ref, customerService) : null,
                  style: _primaryButtonStyle(),
                  child: Text(hasCustomerService ? '打开客服' : '客服暂未配置', style: _buttonTextStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumAboutPage extends ConsumerStatefulWidget {
  const PremiumAboutPage({super.key});

  @override
  ConsumerState<PremiumAboutPage> createState() => _PremiumAboutPageState();
}

class _PremiumAboutPageState extends ConsumerState<PremiumAboutPage> {
  int _versionTapCount = 0;

  void _openDiagnostics() {
    _versionTapCount += 1;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      context.pushNamed('diagnostics');
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appInfoProvider).valueOrNull?.presentVersion;
    final versionText = version == null || version.trim().isEmpty ? '--' : version;
    return _PremiumScaffold(
      title: '关于 4376',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.bolt_rounded, size: 64, color: Color(0xFF2563EB)),
          const Gap(16),
          const Center(child: Text('4376', style: BrandDesktopText.heroStatus)),
          const Gap(6),
          const Center(child: Text('安全、极速、无界', style: BrandDesktopText.bodySecondary)),
          const Gap(28),
          _InputCard(
            child: Column(
              children: [
                _AboutRow(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  onTap: () => context.pushNamed('privacyPolicy'),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _AboutRow(
                  icon: Icons.description_outlined,
                  title: '用户协议',
                  onTap: () => context.pushNamed('termsOfService'),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _AboutRow(
                  icon: Icons.info_outline_rounded,
                  title: '软件版本',
                  trailing: 'v$versionText',
                  onTap: _openDiagnostics,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.title, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: BrandDesktopColors.accent, size: 22),
      title: Text(title, style: BrandDesktopText.bodyPrimary),
      trailing: trailing == null
          ? const Icon(Icons.chevron_right_rounded, color: BrandDesktopColors.textMuted)
          : Text(trailing!, style: BrandDesktopText.bodySecondary),
      onTap: onTap,
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
              title: const Text('全局代理模式', style: BrandDesktopText.sectionTitle),
              subtitle: Text(isGlobalMode ? '所有流量将通过 4376 传输' : '智能分流，仅代理必要流量', style: BrandDesktopText.caption),
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
    final isDesktop = PlatformUtils.isWindows;
    if (!isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const _PremiumBackButton(),
          title: Text(title),
          centerTitle: false,
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          titleTextStyle: BrandText.pageTitle,
          toolbarHeight: 72,
        ),
        body: child,
      );
    }
    return DesktopTheme(
      child: DesktopBackdrop(
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Column(
                children: [
                  const Gap(10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopRoundIcon(icon: Icons.arrow_back_ios_new_rounded, onTap: () => _goBack(context)),
                      Text(title, style: BrandDesktopText.pageTitle),
                      const SizedBox(width: 38),
                    ],
                  ),
                  const Gap(12),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRoundIcon extends StatelessWidget {
  const _TopRoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
      ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed('home');
  }
}

class _PremiumBackButton extends StatelessWidget {
  const _PremiumBackButton();

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isWindows) return const DesktopBackButton();
    return IconButton(
      tooltip: '返回',
      onPressed: () => _goBack(context),
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
            const Icon(Icons.person_outline_rounded, size: 56, color: Color(0xFF2563EB)),
            const Gap(14),
            const Text('请先登录', style: BrandDesktopText.sectionTitle),
            const Gap(6),
            const Text('登录后可查看会员权益与续费入口', style: BrandDesktopText.bodySecondary),
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
                  style: BrandDesktopText.sectionTitle.copyWith(color: Colors.white, fontSize: 17),
                ),
                const Gap(4),
                Text('账号 ${_maskUser(session.email)}', style: BrandDesktopText.caption.copyWith(color: Colors.white60)),
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
                    Text(title, style: BrandDesktopText.sectionTitle),
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
                        style: BrandDesktopText.caption.copyWith(
                          color: const Color(0xFF5C4000),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(description, style: BrandDesktopText.bodySecondary),
              ],
            ),
          ),
          Text(
            '咨询',
            style: BrandDesktopText.sectionTitle.copyWith(
              color: selected ? BrandDesktopColors.accent : BrandDesktopColors.textPrimary,
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

class _InviteStatsGrid extends StatelessWidget {
  const _InviteStatsGrid({required this.stat});

  final PremiumInviteStat stat;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _InviteStatTile(label: '已邀请', value: '${stat.registeredUserCount}', suffix: '人'),
        _InviteStatTile(label: '返利比例', value: '${stat.commissionRatePercent}', suffix: '%'),
        _InviteStatTile(label: '可用佣金', value: _formatMoney(stat.availableCommissionBalanceCents)),
        _InviteStatTile(label: '确认中', value: _formatMoney(stat.pendingCommissionAmountCents)),
      ],
    );
  }
}

class _InviteStatTile extends StatelessWidget {
  const _InviteStatTile({required this.label, required this.value, this.suffix});

  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: BrandDesktopText.caption.copyWith(color: BrandDesktopColors.textMuted)),
          const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandDesktopText.sectionTitle.copyWith(fontSize: 22),
                ),
              ),
              if (suffix != null) ...[
                const Gap(2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(suffix!, style: BrandDesktopText.caption),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteCodeSection extends StatelessWidget {
  const _InviteCodeSection({
    required this.codes,
    required this.creatingCode,
    required this.onCreate,
    required this.onCopy,
  });

  final List<PremiumInviteCode> codes;
  final bool creatingCode;
  final VoidCallback onCreate;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return _InputCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('邀请码', style: BrandDesktopText.sectionTitle)),
                TextButton.icon(
                  onPressed: creatingCode ? null : onCreate,
                  icon: creatingCode
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(creatingCode ? '生成中' : '生成'),
                ),
              ],
            ),
            const Gap(8),
            if (codes.isEmpty)
              const Text('暂无可用邀请码，请点击生成。', style: BrandDesktopText.bodySecondary)
            else
              ...codes.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 18, color: BrandDesktopColors.accent),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            item.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BrandDesktopText.bodyPrimary.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: '复制邀请码',
                          onPressed: () => onCopy(item.code),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumErrorPanel extends StatelessWidget {
  const _PremiumErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFEF4444)),
            const Gap(14),
            const Text('加载失败', style: BrandDesktopText.sectionTitle),
            const Gap(6),
            Text(message, textAlign: TextAlign.center, style: BrandDesktopText.bodySecondary),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onRetry,
                style: _primaryButtonStyle(),
                child: const Text('重试', style: _buttonTextStyle),
              ),
            ),
          ],
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
                Text(title, style: BrandDesktopText.sectionTitle),
                const Gap(3),
                Text(subtitle, style: BrandDesktopText.bodySecondary),
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
      child: Text(label, style: BrandDesktopText.bodySecondary.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

ButtonStyle _primaryButtonStyle() => BrandDesktopButtons.primary(height: 48);

const _buttonTextStyle = BrandDesktopText.buttonLabel;

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

String _formatMoney(int cents) {
  final amount = cents / 100;
  if (amount == amount.roundToDouble()) return '¥${amount.toStringAsFixed(0)}';
  return '¥${amount.toStringAsFixed(2)}';
}

String _failureMessage(Object? error, {required String fallback}) {
  if (error is AuthServerMessageFailure) return error.message;
  if (error is AuthInvalidCredentialsFailure) return error.message ?? '请求参数不正确';
  if (error is AuthTokenExpiredFailure) return '登录已过期，请重新登录';
  if (error is AuthNotLoggedInFailure) return '请先登录账号';
  if (error is AuthNetworkFailure) return error.message ?? '网络连接失败，请稍后重试';
  if (error is AuthBadResponseFailure) return error.message ?? '服务器返回异常';
  return fallback;
}

String _ticketSubject(String message) {
  final firstLine = message
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => 'APP 问题反馈');
  final normalized = firstLine.length > 24 ? '${firstLine.substring(0, 24)}…' : firstLine;
  return 'APP反馈：$normalized';
}

String _ticketMessage({required String message, required String contact, required String email}) {
  final contactText = contact.trim().isEmpty ? '未填写' : contact.trim();
  return [message.trim(), '', '---', '来源：4376 APP', '账号：${_maskUser(email)}', '联系方式：$contactText'].join('\n');
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
