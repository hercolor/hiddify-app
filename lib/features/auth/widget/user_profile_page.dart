import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/widget/spaced_list_widget.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class UserProfilePage extends HookConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        final pair = t.presentError(error);
        ref
            .read(inAppNotificationControllerProvider)
            .showErrorToast(pair.message == null ? pair.type : '${pair.type}\n${pair.message}');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('会员')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: authState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LoginForm(errorText: t.presentError(error).type),
            data: (state) {
              if (state.isInitializing) {
                return const Center(child: CircularProgressIndicator());
              }
              final session = state.session;
              if (session == null) return const _LoginForm();
              return _MemberCenter(session: session);
            },
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends HookConsumerWidget {
  const _LoginForm({this.errorText});

  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final theme = Theme.of(context);

    Future<void> submit() async {
      if (isLoading) return;
      if (!(formKey.currentState?.validate() ?? false)) return;
      await ref.read(authNotifierProvider.notifier).login(emailController.text, passwordController.text);
      if (!context.mounted) return;
      if (ref.read(authNotifierProvider).valueOrNull?.isLoggedIn == true) {
        context.goNamed('home');
      }
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/logo.png', height: 44),
                      const SizedBox(width: 12),
                      Expanded(child: Text('登录 4376加速', style: theme.textTheme.headlineSmall)),
                    ],
                  ),
                  const Text('使用邮箱和密码登录后，将自动获取你的会员套餐和订阅信息。'),
                  if (errorText != null)
                    Text(errorText!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (value) {
                      final input = value?.trim() ?? '';
                      if (input.isEmpty) return '请输入邮箱';
                      if (!input.contains('@')) return '邮箱格式不正确';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (value) => (value == null || value.isEmpty) ? '请输入密码' : null,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  FilledButton.icon(
                    onPressed: isLoading ? null : submit,
                    icon: isLoading
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login_rounded),
                    label: const Text('登录'),
                  ),
                ].spaceBy(height: 16),
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
      children: [
        _AccountCard(session: session),
        _PlanCard(subscription: subscription),
        _TrafficCard(subscription: subscription),
        _SupportCard(subscription: subscription),
      ].spaceBy(height: 12),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.workspace_premium_rounded)),
            title: const Text('4376加速会员'),
            subtitle: Text(session.email),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final expiredAt = subscription?.expiredAt;
    return Card(
      child: Column(
        children: [
          _PlanActionTile(subscription: subscription),
          const Divider(height: 1),
          _InfoTile(icon: Icons.event_available_rounded, title: '到期时间', value: _formatExpiredAt(expiredAt)),
          const Divider(height: 1),
          _InfoTile(icon: Icons.devices_rounded, title: '设备数量', value: _formatDeviceLimit(subscription)),
        ],
      ),
    );
  }
}

class _PlanActionTile extends HookConsumerWidget {
  const _PlanActionTile({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
          child: const Text('续费'),
        ),
        OutlinedButton(
          onPressed: () => _openCustomerService(context, ref, subscription?.customerService),
          child: const Text('升级'),
        ),
      ],
    );

    final info = Row(
      children: [
        const Icon(Icons.card_membership_rounded),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前套餐', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(_displayText(subscription?.planName), style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
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

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final used = subscription?.usedTraffic;
    final remaining = subscription?.remainingTraffic;
    return Card(
      child: Column(
        children: [
          _InfoTile(icon: Icons.data_usage_rounded, title: '已用流量', value: used == null ? '--' : _formatTrafficGb(used)),
          const Divider(height: 1),
          _InfoTile(
            icon: Icons.battery_5_bar_rounded,
            title: '剩余流量',
            value: remaining == null ? '--' : _formatTrafficGb(remaining),
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
        context.goNamed('diagnostics');
      }
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('联系客服'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _openCustomerService(context, ref, subscription?.customerService),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed('privacyPolicy'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushNamed('termsOfService'),
          ),
          const Divider(height: 1),
          appInfo.when(
            data: (info) => ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('App 版本'),
              subtitle: Text(info.presentVersion),
              onTap: openDiagnostics,
            ),
            error: (_, _) =>
                const ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('App 版本'), subtitle: Text('未获取')),
            loading: () => const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('App 版本'),
              subtitle: Text('读取中...'),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('退出登录'),
            enabled: !isLoading,
            onTap: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
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
  if (!launched) {
    notification.showErrorToast('无法打开客服，请稍后重试');
  }
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(value));
  }
}
