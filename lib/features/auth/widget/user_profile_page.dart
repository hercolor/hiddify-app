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
            BoxShadow(
              color: BrandColors.signalBlue.withValues(alpha: .15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
      children: [
        _HeroMemberCard(session: session, subscription: subscription),
        const Gap(14),
        _TrafficCard(subscription: subscription),
        const Gap(14),
        _SupportCard(subscription: subscription),
      ],
    );
  }
}

class _HeroMemberCard extends HookConsumerWidget {
  const _HeroMemberCard({required this.session, required this.subscription});

  final AuthSession session;
  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2D3E), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(BrandRadii.lg),
        boxShadow: [
          BoxShadow(color: BrandColors.slate.withValues(alpha: .26), blurRadius: 22, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MemberField(label: '账号', value: _maskAccount(session.email), dark: true),
              ),
              _SmallLightButton(
                label: '续费',
                onTap: () => _openCustomerService(context, ref, subscription?.customerService),
              ),
              const Gap(8),
              _SmallLightButton(
                label: '升级',
                onTap: () => _openCustomerService(context, ref, subscription?.customerService),
              ),
            ],
          ),
          const Gap(18),
          Row(
            children: [
              Expanded(
                child: _MemberField(
                  label: '当前套餐',
                  value: _displayText(subscription?.planName),
                  prominent: true,
                  dark: true,
                ),
              ),
              const Gap(14),
              Expanded(
                child: _MemberField(label: '到期时间', value: _formatExpiredAt(subscription?.expiredAt), dark: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberField extends StatelessWidget {
  const _MemberField({required this.label, required this.value, this.prominent = false, this.dark = false});

  final String label;
  final String value;
  final bool prominent;
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
          style: (prominent ? theme.textTheme.titleLarge : theme.textTheme.titleSmall)?.copyWith(
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
          color: Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
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

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final used = subscription?.usedTraffic;
    final remaining = subscription?.remainingTraffic;
    return Row(
      children: [
        Expanded(
          child: _MetricMiniCard(
            icon: Icons.data_usage_rounded,
            title: '已用流量',
            value: used == null ? '--' : _formatTrafficGb(used),
            color: BrandColors.signalBlue,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _MetricMiniCard(
            icon: Icons.battery_5_bar_rounded,
            title: '剩余流量',
            value: remaining == null ? '--' : _formatTrafficGb(remaining),
            color: BrandColors.success,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _MetricMiniCard(
            icon: Icons.devices_rounded,
            title: '设备数量',
            value: _formatDeviceLimit(subscription),
            color: BrandColors.iceCyan,
          ),
        ),
      ],
    );
  }
}

class _MetricMiniCard extends StatelessWidget {
  const _MetricMiniCard({required this.icon, required this.title, required this.value, required this.color});

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.border),
        boxShadow: BrandShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandIcon(size: 34, icon: icon),
          const Gap(8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          const Gap(4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends HookConsumerWidget {
  const _SupportCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
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
          trailing: Icons.open_in_new_rounded,
          onTap: () => _openCustomerService(context, ref, subscription?.customerService),
        ),
        const Divider(),
        _ActionTile(icon: Icons.privacy_tip_outlined, title: '隐私政策', onTap: () => context.pushNamed('privacyPolicy')),
        const Divider(),
        _ActionTile(icon: Icons.article_outlined, title: '用户协议', onTap: () => context.pushNamed('termsOfService')),
        const Divider(),
        appInfo.when(
          data: (info) => _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'App 版本',
            subtitle: info.presentVersion,
            onTap: openDiagnostics,
            showChevron: false,
          ),
          error: (_, _) =>
              const _ActionTile(icon: Icons.info_outline_rounded, title: 'App 版本', subtitle: '未获取', showChevron: false),
          loading: () => const _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'App 版本',
            subtitle: '读取中...',
            showChevron: false,
          ),
        ),
        const Divider(),
        _ActionTile(
          icon: Icons.logout_rounded,
          title: '退出登录',
          titleColor: BrandColors.error,
          showChevron: false,
          onTap: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
        ),
      ],
    );
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
        borderRadius: BorderRadius.circular(BrandRadii.lg),
        border: Border.all(color: BrandColors.border),
        boxShadow: BrandShadows.card,
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.titleColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? trailing;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: BrandIcon(size: 40, icon: icon),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: titleColor ?? BrandColors.slate)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: showChevron || trailing != null
          ? Icon(trailing ?? Icons.chevron_right_rounded, color: BrandColors.subtle)
          : null,
      onTap: onTap,
    );
  }
}

String _formatExpiredAt(DateTime? expiredAt) {
  if (expiredAt == null) return '--';
  return DateFormat('yyyy/MM/dd HH:mm').format(expiredAt.toLocal());
}

String _formatTrafficGb(int bytes) {
  final gb = bytes / 1024 / 1024 / 1024;
  final digits = gb >= 10 ? 1 : 2;
  return '${gb.toStringAsFixed(digits)} GB';
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
