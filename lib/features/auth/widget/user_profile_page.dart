import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/customer_service_uri.dart';
import 'package:hiddify/features/auth/widget/desktop_membership_page.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class UserProfilePage extends HookConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final authState = ref.watch(authNotifierProvider);
    final currentState = authState.valueOrNull;
    final showingLogin = currentState?.session == null;

    ref.listen(authNotifierProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        final pair = t.presentError(error);
        ref
            .read(inAppNotificationControllerProvider)
            .showErrorToast(pair.message == null ? pair.type : '${pair.type}\n${pair.message}');
      }
    });

    if (PlatformUtils.isWindows) {
      return DesktopMembershipPage(authState: authState, errorText: authState.readableError(t));
    }

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: showingLogin,
      appBar: showingLogin ? null : AppBar(toolbarHeight: 72, title: const Text('我的账号')),
      body: BrandScaffoldBackground(
        showHalos: !showingLogin,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _UserProfileContent(authState: authState, errorText: authState.readableError(t)),
          ),
        ),
      ),
    );
  }
}

class _UserProfileContent extends StatelessWidget {
  const _UserProfileContent({required this.authState, required this.errorText});

  final AsyncValue<AuthState> authState;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final currentState = authState.valueOrNull;
    if (currentState?.isInitializing == true || (authState.isLoading && currentState == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    final session = currentState?.session;
    if (session != null) return _MemberCenter(session: session);

    return _LoginForm(errorText: errorText);
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({this.errorText});

  final String? errorText;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ValueNotifier<String?> _emailError = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _passwordError = ValueNotifier<String?>(null);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearEmailError);
    _passwordController.addListener(_clearPasswordError);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearEmailError);
    _passwordController.removeListener(_clearPasswordError);
    _emailController.dispose();
    _passwordController.dispose();
    _emailError.dispose();
    _passwordError.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_validateInputs()) return;
    final stopwatch = Stopwatch()..start();
    setState(() => _isSubmitting = true);
    DiagnosticEventBuffer.addSafe('loginRequestStart');
    try {
      await ref.read(authNotifierProvider.notifier).login(_emailController.text, _passwordController.text);
      stopwatch.stop();
      final loggedIn = ref.read(authNotifierProvider).valueOrNull?.isLoggedIn == true;
      DiagnosticEventBuffer.addSafe('loginRequestEnd success=$loggedIn elapsedMs=${stopwatch.elapsedMilliseconds}');
      if (!mounted) return;
      if (loggedIn) {
        context.goNamed('home');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final nextEmailError = email.isEmpty
        ? '请输入邮箱'
        : !email.contains('@')
        ? '邮箱格式不正确'
        : null;
    final nextPasswordError = password.isEmpty ? '请输入密码' : null;
    _emailError.value = nextEmailError;
    _passwordError.value = nextPasswordError;
    return nextEmailError == null && nextPasswordError == null;
  }

  void _clearEmailError() {
    if (_emailError.value != null) {
      _emailError.value = null;
    }
  }

  void _clearPasswordError() {
    if (_passwordError.value != null) {
      _passwordError.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isSubmitting;
    final theme = Theme.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 42),
                  const _LoginMark(),
                  const Gap(24),
                  const Text(
                    '4376',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: BrandColors.signalBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  const Gap(8),
                  Text('安全、极速、无界', style: theme.textTheme.bodyMedium),
                  const Gap(48),
                  if (widget.errorText != null) ...[
                    Text(
                      widget.errorText!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: BrandColors.error),
                    ),
                    const Gap(14),
                  ],
                  ValueListenableBuilder<String?>(
                    valueListenable: _emailError,
                    builder: (context, errorText, _) {
                      return TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enableSuggestions: false,
                        autocorrect: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        decoration: InputDecoration(
                          hintText: '邮箱账号',
                          errorText: errorText,
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                      );
                    },
                  ),
                  const Gap(16),
                  ValueListenableBuilder<String?>(
                    valueListenable: _passwordError,
                    builder: (context, errorText, _) {
                      return TextField(
                        controller: _passwordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        decoration: InputDecoration(
                          hintText: '密码',
                          errorText: errorText,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                        onSubmitted: (_) => _submit(),
                      );
                    },
                  ),
                  const Gap(24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _GradientButton(onPressed: isLoading ? null : _submit, label: '登 录', isLoading: isLoading),
                  ),
                  const SizedBox(height: 44),
                  Text('登录后自动完成加速准备', style: theme.textTheme.bodySmall?.copyWith(color: BrandColors.signalBlue)),
                  const Gap(32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginMark extends StatelessWidget {
  const _LoginMark();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: BrandColors.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: BrandColors.signalBlue.withOpacity(.15), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: const Center(child: Icon(Icons.shield_rounded, size: 52, color: BrandColors.signalBlue)),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.label, this.isLoading = false});

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : BrandGradients.primary,
        color: onPressed == null ? BrandColors.subtle : null,
        borderRadius: BorderRadius.circular(BrandRadii.md),
        boxShadow: onPressed == null ? null : BrandShadows.glow(BrandColors.signalBlue, alpha: .16),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
        child: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}

class _MemberCenter extends StatelessWidget {
  const _MemberCenter({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final subscription = session.subscription;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 104),
      children: [
        _HeroMemberCard(session: session, subscription: subscription),
        const Gap(24),
        const _SectionLabel('路由设置'),
        const Gap(8),
        const _MobileRouteModeCard(),
        const Gap(24),
        const _SectionLabel('其他功能'),
        const Gap(8),
        _SupportCard(subscription: subscription),
        const Gap(24),
        _LogoutButton(),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: BrandColors.muted, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _HeroMemberCard extends HookConsumerWidget {
  const _HeroMemberCard({required this.session, required this.subscription});

  final AuthSession session;
  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final planName = _displayText(subscription?.planName);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2D3E), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: BrandColors.slate.withOpacity(.26), blurRadius: 22, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.10), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: Colors.white),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _maskAccount(session.email),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            '设备：${_formatDeviceLimit(subscription)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              _PlanBadge(label: planName),
            ],
          ),
          const Gap(32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _MemberField(label: '到期时间', value: _formatExpiredAt(subscription?.expiredAt), dark: true),
              ),
              const Gap(12),
              _SmallLightButton(label: '续费', onTap: () => context.pushNamed('premiumRenewal')),
              const Gap(8),
              _SmallLightButton(label: '升级', onTap: () => context.pushNamed('premiumRenewal')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFD700).withOpacity(.36), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF5C4000)),
          const Gap(4),
          Text(
            label == '--' ? '4376 Pro' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF5C4000), fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MemberField extends StatelessWidget {
  const _MemberField({required this.label, required this.value, this.dark = false});

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: dark ? Colors.white60 : BrandColors.muted)),
        const Gap(5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: dark ? Colors.white : BrandColors.slate,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SmallLightButton extends StatelessWidget {
  const _SmallLightButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.14)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

String _formatDeviceLimit(UserSubscription? subscription) {
  final online = subscription?.onlineDevices;
  final max = subscription?.maxDevices;
  if (online == null && max == null) return '--';
  return '${online?.toString() ?? '--'} / ${max?.toString() ?? '--'}';
}

String _displayText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return '--';
  return trimmed;
}

String _maskAccount(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '--';
  final at = trimmed.indexOf('@');
  if (at <= 1) return '${trimmed.substring(0, 1)}***';
  return '${trimmed.substring(0, 1)}***${trimmed.substring(at)}';
}

class _MobileRouteModeCard extends ConsumerWidget {
  const _MobileRouteModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobalMode = ref.watch(ConfigOptions.globalRouteMode);
    return _PremiumCard(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          title: const Text(
            '全局代理模式',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827)),
          ),
          subtitle: Text(
            isGlobalMode ? '所有流量将通过 4376 传输' : '智能分流，仅代理必要流量',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          activeThumbColor: BrandColors.signalBlue,
          value: isGlobalMode,
          onChanged: (value) => ref.read(ConfigOptions.globalRouteMode.notifier).update(value),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGlobalMode ? BrandColors.signalBlue.withOpacity(.10) : BrandColors.mist,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGlobalMode ? Icons.public_rounded : Icons.alt_route_rounded,
              color: isGlobalMode ? BrandColors.signalBlue : BrandColors.subtle,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportCard extends HookConsumerWidget {
  const _SupportCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfo = ref.watch(appInfoProvider);
    final versionTapCount = useState(0);

    void openDiagnostics() {
      versionTapCount.value += 1;
      if (versionTapCount.value >= 7) {
        versionTapCount.value = 0;
        context.pushNamed('diagnostics');
      }
    }

    return _PremiumCard(
      children: [
        _ActionTile(
          icon: Icons.support_agent_rounded,
          title: '联系客服',
          subtitle: '获取套餐与线路支持',
          iconColor: const Color(0xFF007AFF),
          trailing: Icons.open_in_new_rounded,
          onTap: () => _openCustomerService(context, ref, subscription?.customerService),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.card_giftcard_rounded,
          title: '邀请有礼',
          subtitle: '邀请好友了解 4376',
          iconColor: const Color(0xFFFF9500),
          onTap: () => context.pushNamed('premiumInvite'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.feedback_outlined,
          title: '反馈问题',
          iconColor: const Color(0xFF2563EB),
          onTap: () => context.pushNamed('premiumFeedback'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.language_rounded,
          title: '官网链接',
          iconColor: const Color(0xFF10B981),
          onTap: () => context.pushNamed('premiumWebsite'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.settings_outlined,
          title: '高级设置',
          subtitle: '全局/智能路由模式',
          iconColor: const Color(0xFF64748B),
          onTap: () => context.pushNamed('premiumPreferences'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.privacy_tip_outlined,
          title: '隐私政策',
          iconColor: const Color(0xFF34C759),
          onTap: () => context.pushNamed('privacyPolicy'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.article_outlined,
          title: '用户协议',
          iconColor: const Color(0xFFFF9500),
          onTap: () => context.pushNamed('termsOfService'),
        ),
        const _ActionDivider(),
        appInfo.when(
          data: (info) => _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'App 版本',
            subtitle: info.presentVersion,
            iconColor: const Color(0xFF6B7280),
            onTap: openDiagnostics,
          ),
          error: (_, _) => const _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'App 版本',
            subtitle: '未获取',
            iconColor: Color(0xFF6B7280),
          ),
          loading: () => const _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'App 版本',
            subtitle: '读取中...',
            iconColor: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 24, color: Color(0xFFF5F7FA));
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827)),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      trailing: Icon(trailing ?? Icons.chevron_right_rounded, color: BrandColors.subtle),
      onTap: onTap,
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return TextButton(
      onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: BrandColors.error.withOpacity(.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        '退出登录',
        style: TextStyle(color: BrandColors.error, fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _formatExpiredAt(DateTime? expiredAt) {
  if (expiredAt == null) return '--';
  return DateFormat('yyyy/MM/dd HH:mm').format(expiredAt.toLocal());
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
