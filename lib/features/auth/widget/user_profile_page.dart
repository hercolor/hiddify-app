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
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
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

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(toolbarHeight: 72, title: const Text('会员中心')),
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _buildCount = 0;
  int _emailInputCount = 0;
  int _passwordInputCount = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isLoading) async {
    if (isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final stopwatch = Stopwatch()..start();
    DiagnosticEventBuffer.addSafe('loginRequestStart');
    await ref.read(authNotifierProvider.notifier).login(_emailController.text, _passwordController.text);
    stopwatch.stop();
    final loggedIn = ref.read(authNotifierProvider).valueOrNull?.isLoggedIn == true;
    DiagnosticEventBuffer.addSafe('loginRequestEnd success=$loggedIn elapsedMs=${stopwatch.elapsedMilliseconds}');
    if (!mounted) return;
    if (loggedIn) {
      context.goNamed('home');
    }
  }

  void _onEmailChanged(String _) {
    _emailInputCount += 1;
    DiagnosticEventBuffer.addSafe('emailInputChanged count=$_emailInputCount');
  }

  void _onPasswordChanged(String _) {
    _passwordInputCount += 1;
    DiagnosticEventBuffer.addSafe('passwordInputChanged count=$_passwordInputCount');
  }

  @override
  Widget build(BuildContext context) {
    _buildCount += 1;
    final isLoading = ref.watch(authNotifierProvider.select((value) => value.isLoading));
    final theme = Theme.of(context);
    DiagnosticEventBuffer.addSafe('loginPageBuildCount=$_buildCount isLoading=$isLoading');

    return SafeArea(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 104),
        children: [
          const Center(child: RepaintBoundary(child: BrandMark(size: 54))),
          const Gap(34),
          DecoratedBox(
            decoration: BoxDecoration(
              color: BrandColors.card.withValues(alpha: .98),
              borderRadius: BorderRadius.circular(BrandRadii.xl),
              border: Border.all(color: BrandColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('欢迎使用 4376', style: theme.textTheme.headlineSmall),
                    const Gap(8),
                    Text('稳定、安全、快速的网络加速体验', style: theme.textTheme.bodyMedium),
                    if (widget.errorText != null) ...[
                      const Gap(14),
                      Text(widget.errorText!, style: theme.textTheme.bodyMedium?.copyWith(color: BrandColors.error)),
                    ],
                    const Gap(24),
                    TextFormField(
                      controller: _emailController,
                      onChanged: _onEmailChanged,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: '邮箱账号',
                        hintText: '请输入邮箱',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) return '请输入邮箱';
                        if (!input.contains('@')) return '邮箱格式不正确';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const Gap(14),
                    TextFormField(
                      controller: _passwordController,
                      onChanged: _onPasswordChanged,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '登录密码',
                        hintText: '请输入密码',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? '请输入密码' : null,
                      onFieldSubmitted: (_) => _submit(isLoading),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () {}, child: const Text('忘记密码')),
                    ),
                    const Gap(4),
                    _GradientButton(
                      onPressed: isLoading ? null : () => _submit(isLoading),
                      label: '登录',
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Gap(24),
          Center(child: Text('登录后将自动准备可用线路', style: theme.textTheme.bodySmall)),
        ],
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BrandColors.signalBlue, BrandColors.iceCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(BrandRadii.xl),
        boxShadow: BrandShadows.glow(BrandColors.signalBlue, alpha: .18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 36, dark: true),
              const Spacer(),
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
          const Gap(24),
          Text('当前套餐', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .82))),
          const Gap(4),
          Text(
            _displayText(subscription?.planName),
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const Gap(14),
          Text(session.email, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: .82))),
          const Gap(18),
          _LightInfoRow(
            icon: Icons.event_available_rounded,
            label: '到期时间',
            value: _formatExpiredAt(subscription?.expiredAt),
          ),
          const Gap(10),
          _LightInfoRow(icon: Icons.devices_rounded, label: '设备数量', value: _formatDeviceLimit(subscription)),
        ],
      ),
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
          color: Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .24)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

class _LightInfoRow extends StatelessWidget {
  const _LightInfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const Gap(8),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .82))),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ],
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

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final used = subscription?.usedTraffic;
    final remaining = subscription?.remainingTraffic;
    return _PremiumCard(
      children: [
        _InfoTile(icon: Icons.data_usage_rounded, title: '已用流量', value: used == null ? '--' : _formatTrafficGb(used)),
        const Divider(),
        _InfoTile(
          icon: Icons.battery_5_bar_rounded,
          title: '剩余流量',
          value: remaining == null ? '--' : _formatTrafficGb(remaining),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          BrandIcon(size: 42, icon: icon),
          const Gap(12),
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
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
  final uri = _customerServiceUri(customerService);
  if (uri == null) {
    notification.showInfoToast('客服暂未配置');
    return;
  }

  final launched = await UriUtils.tryLaunch(uri);
  if (!launched) notification.showErrorToast('无法打开客服，请稍后重试');
}

Uri? _customerServiceUri(String? customerService) {
  final trimmed = customerService?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (_looksLikeEmail(trimmed)) return Uri(scheme: 'mailto', path: trimmed);
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.isEmpty) return null;
  return uri;
}

bool _looksLikeEmail(String value) {
  if (value.contains('://') || value.contains(' ')) return false;
  final parts = value.split('@');
  return parts.length == 2 && parts[0].isNotEmpty && parts[1].contains('.');
}
