import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/customer_service_uri.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class DesktopMembershipPage extends StatelessWidget {
  const DesktopMembershipPage({super.key, required this.authState, required this.errorText});

  final AsyncValue<AuthState> authState;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final currentState = authState.valueOrNull;
    if (currentState?.isInitializing == true || (authState.isLoading && currentState == null)) {
      return const DesktopPageScaffold(
        title: '会员中心',
        subtitle: '正在恢复账号状态',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final session = currentState?.session;
    if (session == null) return _DesktopLogin(errorText: errorText);
    return _DesktopMemberCenter(session: session);
  }
}

class _DesktopLogin extends ConsumerStatefulWidget {
  const _DesktopLogin({this.errorText});

  final String? errorText;

  @override
  ConsumerState<_DesktopLogin> createState() => _DesktopLoginState();
}

class _DesktopLoginState extends ConsumerState<_DesktopLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_validate()) return;
    final stopwatch = Stopwatch()..start();
    setState(() => _isSubmitting = true);
    DiagnosticEventBuffer.addSafe('loginRequestStart');
    try {
      await ref.read(authNotifierProvider.notifier).login(_emailController.text, _passwordController.text);
      stopwatch.stop();
      final loggedIn = ref.read(authNotifierProvider).valueOrNull?.isLoggedIn == true;
      DiagnosticEventBuffer.addSafe('loginRequestEnd success=$loggedIn elapsedMs=${stopwatch.elapsedMilliseconds}');
      if (!mounted) return;
      if (loggedIn) context.goNamed('home');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? '请输入邮箱'
          : !email.contains('@')
          ? '邮箱格式不正确'
          : null;
      _passwordError = password.isEmpty ? '请输入密码' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopTheme(
      child: DesktopBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 326),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DesktopLoginMark(),
                    const Gap(24),
                    const Text(
                      '4376',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: BrandDesktopColors.accent,
                        letterSpacing: 2,
                      ),
                    ),
                    const Gap(8),
                    Text('安全、极速、无界', style: Theme.of(context).textTheme.bodyMedium),
                    const Gap(42),
                    if (widget.errorText != null) ...[
                      Text(
                        widget.errorText!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.error),
                      ),
                      const Gap(14),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: '邮箱账号',
                        errorText: _emailError,
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_emailError != null) setState(() => _emailError = null);
                      },
                    ),
                    const Gap(16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: '密码',
                        errorText: _passwordError,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) {
                        if (_passwordError != null) setState(() => _passwordError = null);
                      },
                    ),
                    const Gap(24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DesktopGradientButton(
                        label: '登 录',
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ),
                    const Gap(42),
                    Text(
                      '登录后自动完成加速准备',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopLoginMark extends StatelessWidget {
  const _DesktopLoginMark();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: BrandDesktopColors.cardSolid,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: BrandDesktopColors.accent.withOpacity(.15), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: const Center(child: Icon(Icons.shield_rounded, size: 52, color: BrandDesktopColors.accent)),
      ),
    );
  }
}

class _DesktopMemberCenter extends HookConsumerWidget {
  const _DesktopMemberCenter({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = session.subscription;
    final appInfo = ref.watch(appInfoProvider);
    final versionTapCount = useState(0);

    void openDiagnostics() {
      versionTapCount.value += 1;
      if (versionTapCount.value >= 7) {
        versionTapCount.value = 0;
        context.pushNamed('diagnostics');
      }
    }

    return DesktopPageScaffold(
      title: '我的账号',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final plan = _PlanCard(session: session, subscription: subscription);
          final actions = _MemberActions(
            subscription: subscription,
            version: appInfo.valueOrNull?.presentVersion,
            onVersionTap: openDiagnostics,
          );
          if (narrow) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                plan,
                const Gap(22),
                const _DesktopSectionLabel('路由设置'),
                const Gap(8),
                const _RouteModeSwitchCard(),
                const Gap(22),
                const _DesktopSectionLabel('其他功能'),
                const Gap(8),
                actions,
                const Gap(16),
                _DesktopLegalFooter(
                  subscription: subscription,
                  version: appInfo.valueOrNull?.presentVersion,
                  onVersionTap: openDiagnostics,
                ),
                const Gap(24),
                const _DesktopLogoutButton(),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              plan,
              const Gap(22),
              const _DesktopSectionLabel('路由设置'),
              const Gap(8),
              const _RouteModeSwitchCard(),
              const Gap(22),
              const _DesktopSectionLabel('其他功能'),
              const Gap(8),
              actions,
              const Gap(16),
              _DesktopLegalFooter(
                subscription: subscription,
                version: appInfo.valueOrNull?.presentVersion,
                onVersionTap: openDiagnostics,
              ),
              const Gap(24),
              const _DesktopLogoutButton(),
            ],
          );
        },
      ),
    );
  }
}

class _RouteModeSwitchCard extends ConsumerWidget {
  const _RouteModeSwitchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobalMode = ref.watch(ConfigOptions.globalRouteMode);
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        title: Text(
          '全局代理模式',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          isGlobalMode ? '所有流量将通过 4376 传输' : '智能分流，仅代理必要流量',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textSecondary),
        ),
        activeThumbColor: BrandDesktopColors.accent,
        value: isGlobalMode,
        onChanged: (value) => ref.read(ConfigOptions.globalRouteMode.notifier).update(value),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGlobalMode ? BrandDesktopColors.accent.withOpacity(.10) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.public_rounded,
            color: isGlobalMode ? BrandDesktopColors.accent : BrandDesktopColors.textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DesktopSectionLabel extends StatelessWidget {
  const _DesktopSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: BrandDesktopColors.textSecondary, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.session, required this.subscription});

  final AuthSession session;
  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planName = _displayText(subscription?.planName);
    return DesktopCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF2A2D3E), Color(0xFF111827)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white10,
      padding: const EdgeInsets.all(18),
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
                            _maskUser(session.email),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                          const Gap(4),
                          Text(
                            '设备：${_formatDeviceLimit(subscription)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              _DesktopPlanBadge(label: planName),
            ],
          ),
          const Gap(32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PlanField(label: '到期时间', value: _formatExpiredAt(subscription?.expiredAt), dark: true),
              ),
              const Gap(12),
              _SmallPlanButton(label: '续费', onPressed: () => context.pushNamed('premiumRenewal')),
              const Gap(8),
              _SmallPlanButton(label: '升级', onPressed: () => context.pushNamed('premiumRenewal')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopPlanBadge extends StatelessWidget {
  const _DesktopPlanBadge({required this.label});

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

class _PlanField extends StatelessWidget {
  const _PlanField({required this.label, required this.value, this.dark = false});

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: dark ? Colors.white60 : BrandDesktopColors.textMuted),
        ),
        const Gap(5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: dark ? Colors.white : BrandDesktopColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SmallPlanButton extends StatelessWidget {
  const _SmallPlanButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(52, 34)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      foregroundColor: const WidgetStatePropertyAll(Color(0xFFFFD700)),
      backgroundColor: WidgetStatePropertyAll(Colors.white.withOpacity(.10)),
      side: WidgetStatePropertyAll(BorderSide(color: Colors.white.withOpacity(.12))),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    final child = Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800));
    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _MemberActions extends ConsumerWidget {
  const _MemberActions({required this.subscription, required this.version, required this.onVersionTap});

  final UserSubscription? subscription;
  final String? version;
  final VoidCallback onVersionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionRow(
            icon: Icons.card_giftcard_rounded,
            title: '邀请有礼',
            subtitle: '邀请好友得免费时长',
            iconColor: const Color(0xFFFF9500),
            onTap: () => context.pushNamed('premiumInvite'),
          ),
          const _DesktopActionDivider(),
          _ActionRow(
            icon: Icons.feedback_outlined,
            title: '反馈问题',
            iconColor: const Color(0xFF2563EB),
            onTap: () => context.pushNamed('premiumFeedback'),
          ),
          const _DesktopActionDivider(),
          _ActionRow(
            icon: Icons.language_rounded,
            title: '官网链接',
            iconColor: const Color(0xFF10B981),
            onTap: () => context.pushNamed('premiumWebsite'),
          ),
          const _DesktopActionDivider(),
          _ActionRow(
            icon: Icons.settings_outlined,
            title: '高级设置',
            iconColor: const Color(0xFF64748B),
            onTap: () => context.pushNamed('premiumPreferences'),
          ),
        ],
      ),
    );
  }
}

class _DesktopLegalFooter extends ConsumerWidget {
  const _DesktopLegalFooter({required this.subscription, required this.version, required this.onVersionTap});

  final UserSubscription? subscription;
  final String? version;
  final VoidCallback onVersionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textSecondary);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: [
            _FooterLink(label: '联系客服', onTap: () => _openCustomerService(context, ref, subscription?.customerService)),
            _FooterLink(label: '隐私政策', onTap: () => context.pushNamed('privacyPolicy')),
            _FooterLink(label: '用户协议', onTap: () => context.pushNamed('termsOfService')),
          ],
        ),
        const Gap(8),
        GestureDetector(
          onTap: onVersionTap,
          child: Text('版本 ${version == null || version!.isBlank ? '--' : version!}', style: textStyle),
        ),
      ],
    );
  }
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textSecondary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DesktopActionDivider extends StatelessWidget {
  const _DesktopActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 24, color: Color(0xFFF5F7FA));
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.iconColor, this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const Gap(4),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BrandDesktopColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopLogoutButton extends ConsumerWidget {
  const _DesktopLogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return TextButton(
      onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: BrandDesktopColors.error.withOpacity(.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        '退出登录',
        style: TextStyle(color: BrandDesktopColors.error, fontSize: 16, fontWeight: FontWeight.w800),
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

String _formatExpiredAt(DateTime? expiredAt) {
  if (expiredAt == null) return '--';
  return DateFormat('yyyy/MM/dd HH:mm').format(expiredAt.toLocal());
}

String _maskUser(String value) {
  final trimmed = value.trim();
  if (!trimmed.contains('@')) return trimmed.length <= 2 ? '***' : '${trimmed.substring(0, 1)}***';
  final parts = trimmed.split('@');
  return '${parts.first.substring(0, 1)}***@${parts.last}';
}
