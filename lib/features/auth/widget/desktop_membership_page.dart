import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/customer_service_uri.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
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
                      '登录后将自动同步节点',
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
            BoxShadow(
              color: BrandDesktopColors.accent.withValues(alpha: .15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(child: BrandMark(size: 52, showWordmark: false)),
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
      title: '会员中心',
      subtitle: '管理套餐、流量与账号服务',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final plan = _PlanCard(session: session, subscription: subscription);
          final traffic = _TrafficAndDeviceGrid(subscription: subscription);
          final actions = _MemberActions(
            subscription: subscription,
            version: appInfo.valueOrNull?.presentVersion,
            onVersionTap: openDiagnostics,
          );
          if (narrow) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [plan, const Gap(12), traffic, const Gap(12), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Expanded(child: plan),
                    const Gap(16),
                    traffic,
                  ],
                ),
              ),
              const Gap(18),
              Expanded(flex: 4, child: actions),
            ],
          );
        },
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
    return DesktopCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFEAF2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: BrandDesktopColors.accent.withValues(alpha: .24),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PlanField(label: '账号', value: _maskUser(session.email)),
              ),
              const Gap(8),
              _SmallPlanButton(
                label: '续费',
                onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
              ),
              const Gap(6),
              _SmallPlanButton(
                label: '升级',
                filled: true,
                onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
              ),
            ],
          ),
          const Gap(18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PlanField(label: '当前套餐', value: _displayText(subscription?.planName), prominent: true),
              ),
              const Gap(16),
              Expanded(
                child: _PlanField(label: '到期时间', value: _formatExpiredAt(subscription?.expiredAt)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanField extends StatelessWidget {
  const _PlanField({required this.label, required this.value, this.prominent = false});

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textMuted)),
        const Gap(5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (prominent ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleSmall)
              ?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _SmallPlanButton extends StatelessWidget {
  const _SmallPlanButton({required this.label, required this.onPressed, this.filled = false});

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? FilledButton.styleFrom(
            minimumSize: const Size(52, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        : OutlinedButton.styleFrom(
            minimumSize: const Size(52, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
    final child = Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800));
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _TrafficAndDeviceGrid extends StatelessWidget {
  const _TrafficAndDeviceGrid({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final used = subscription?.usedTraffic;
    final remaining = subscription?.remainingTraffic;
    return Row(
      children: [
        Expanded(
          child: _CompactMetricTile(
            icon: Icons.data_usage_rounded,
            label: '已用流量',
            value: used == null ? '--' : _formatTrafficGb(used),
            accent: BrandDesktopColors.accent,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _CompactMetricTile(
            icon: Icons.battery_5_bar_rounded,
            label: '剩余流量',
            value: remaining == null ? '--' : _formatTrafficGb(remaining),
            accent: BrandDesktopColors.success,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _CompactMetricTile(
            icon: Icons.devices_rounded,
            label: '设备数量',
            value: _formatDeviceLimit(subscription),
            accent: BrandDesktopColors.cyan,
          ),
        ),
      ],
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({required this.icon, required this.label, required this.value, required this.accent});

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesktopIconBox(icon: icon, color: accent, size: 30),
          const Gap(7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BrandDesktopColors.textMuted),
          ),
          const Gap(3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BrandDesktopColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberActions extends ConsumerWidget {
  const _MemberActions({required this.subscription, required this.version, required this.onVersionTap});

  final UserSubscription? subscription;
  final String? version;
  final VoidCallback onVersionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionRow(
              icon: Icons.support_agent_rounded,
              title: '联系客服',
              subtitle: '获取套餐与线路支持',
              onTap: () => _openCustomerService(context, ref, subscription?.customerService),
            ),
            _ActionRow(
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              subtitle: '本地显示',
              onTap: () => context.pushNamed('privacyPolicy'),
            ),
            _ActionRow(
              icon: Icons.article_outlined,
              title: '用户协议',
              subtitle: '本地显示',
              onTap: () => context.pushNamed('termsOfService'),
            ),
            _ActionRow(
              icon: Icons.info_outline_rounded,
              title: 'App 版本',
              subtitle: version == null || version!.isBlank ? '--' : version!,
              onTap: onVersionTap,
              showChevron: false,
            ),
            _ActionRow(
              icon: Icons.logout_rounded,
              title: '退出登录',
              subtitle: '清除本机登录状态',
              danger: true,
              showChevron: false,
              onTap: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BrandDesktopColors.error : BrandDesktopColors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BrandDesktopColors.cardElevated.withValues(alpha: .46),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BrandDesktopColors.border),
            ),
            child: Row(
              children: [
                DesktopIconBox(icon: icon, color: color),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: danger ? BrandDesktopColors.error : BrandDesktopColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const Gap(4),
                        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (showChevron) const Icon(Icons.chevron_right_rounded, color: BrandDesktopColors.textMuted),
              ],
            ),
          ),
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

String _formatExpiredAt(DateTime? expiredAt) {
  if (expiredAt == null) return '--';
  return DateFormat('yyyy/MM/dd HH:mm').format(expiredAt.toLocal());
}

String _formatTrafficGb(int bytes) {
  final gb = bytes / 1024 / 1024 / 1024;
  final digits = gb >= 10 ? 1 : 2;
  return '${gb.toStringAsFixed(digits)} GB';
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
