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
    return DesktopPageScaffold(
      title: '会员中心',
      subtitle: '登录后将自动准备可用线路',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: DesktopCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(34),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BrandMark(size: 50, dark: true),
                        const Gap(34),
                        Text(
                          '欢迎使用 4376',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(color: BrandDesktopColors.textPrimary),
                        ),
                        const Gap(8),
                        Text('登录账号后自动同步节点，普通界面不暴露订阅链接。', style: Theme.of(context).textTheme.bodyMedium),
                        if (widget.errorText != null) ...[
                          const Gap(14),
                          Text(
                            widget.errorText!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.error),
                          ),
                        ],
                        const Gap(28),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: '邮箱账号',
                            hintText: '请输入邮箱',
                            errorText: _emailError,
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_emailError != null) setState(() => _emailError = null);
                          },
                        ),
                        const Gap(14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: '登录密码',
                            hintText: '请输入密码',
                            errorText: _passwordError,
                            prefixIcon: const Icon(Icons.key_rounded),
                          ),
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) {
                            if (_passwordError != null) setState(() => _passwordError = null);
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: () {}, child: const Text('忘记密码')),
                        ),
                        const Gap(4),
                        SizedBox(
                          width: double.infinity,
                          child: DesktopGradientButton(
                            label: '登录',
                            icon: Icons.login_rounded,
                            isLoading: _isSubmitting,
                            onPressed: _isSubmitting ? null : _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).width > 980)
                  Expanded(
                    child: Container(
                      height: 520,
                      decoration: const BoxDecoration(
                        gradient: BrandDesktopGradients.primary,
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(BrandDesktopRadii.card)),
                      ),
                      child: const Center(child: BrandMark(size: 96, showWordmark: false, dark: true)),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SizedBox(height: 360, child: plan),
                const Gap(16),
                traffic,
                const Gap(16),
                SizedBox(height: 520, child: actions),
              ],
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
        colors: [Color(0xE61C3355), Color(0xBF0E1729)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: BrandDesktopColors.accent.withValues(alpha: .24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 44, dark: true),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
                child: const Text('续费'),
              ),
              const Gap(10),
              DesktopGradientButton(
                label: '升级',
                icon: Icons.trending_up_rounded,
                onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
              ),
            ],
          ),
          const Spacer(),
          Text('当前套餐', style: Theme.of(context).textTheme.bodyMedium),
          const Gap(8),
          Text(
            _displayText(subscription?.planName),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w900),
          ),
          const Gap(14),
          Text(
            _maskUser(session.email),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.textSecondary),
          ),
          const Gap(22),
          DesktopStatusPill(
            label: '到期 ${_formatExpiredAt(subscription?.expiredAt)}',
            color: BrandDesktopColors.cyan,
            icon: Icons.event_available_rounded,
          ),
        ],
      ),
    );
  }
}

class _TrafficAndDeviceGrid extends StatelessWidget {
  const _TrafficAndDeviceGrid({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final used = subscription?.usedTraffic;
    final remaining = subscription?.remainingTraffic;
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width < 980 ? 1 : 3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.8,
      children: [
        DesktopMetricTile(
          icon: Icons.data_usage_rounded,
          label: '已用流量',
          value: used == null ? '--' : _formatTrafficGb(used),
          accent: BrandDesktopColors.accent,
        ),
        DesktopMetricTile(
          icon: Icons.battery_5_bar_rounded,
          label: '剩余流量',
          value: remaining == null ? '--' : _formatTrafficGb(remaining),
          accent: BrandDesktopColors.success,
        ),
        DesktopMetricTile(
          icon: Icons.devices_rounded,
          label: '设备数量',
          value: _formatDeviceLimit(subscription),
          accent: BrandDesktopColors.cyan,
        ),
      ],
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
      child: ListView(
        padding: const EdgeInsets.all(14),
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
