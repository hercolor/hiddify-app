import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/widget/spaced_list_widget.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/utils/date_time_formatter.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
      appBar: AppBar(title: const Text('用户中心')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: authState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LoginForm(errorText: t.presentError(error).type),
            data: (state) {
              final session = state.session;
              if (session == null) return const _LoginForm();
              return _UserCenter(session: session);
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
                  Text('登录 4376加速', style: theme.textTheme.headlineSmall),
                  const Text('使用邮箱和密码登录后，将自动获取你的 XBoard 订阅信息。'),
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

class _UserCenter extends HookConsumerWidget {
  const _UserCenter({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final subscription = session.subscription;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('当前账号'),
                subtitle: Text(session.email),
              ),
              const Divider(height: 1),
              if (subscription == null)
                const ListTile(
                  leading: Icon(Icons.link_off_rounded),
                  title: Text('暂无订阅信息'),
                  subtitle: Text('请点击刷新订阅重新获取。'),
                )
              else
                _SubscriptionSection(subscription: subscription),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).refreshSubscription(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('刷新订阅'),
        ),
        OutlinedButton.icon(
          onPressed: isLoading || subscription == null
              ? null
              : () => ref.read(authNotifierProvider.notifier).importSubscriptionToProfiles(),
          icon: const Icon(Icons.download_rounded),
          label: const Text('导入到配置'),
        ),
        TextButton.icon(
          onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('退出登录'),
        ),
      ].spaceBy(height: 12),
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({required this.subscription});

  final UserSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final expiredAt = subscription.expiredAt;
    final remaining = subscription.remainingTraffic;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.event_available_rounded),
          title: const Text('到期时间'),
          subtitle: Text(expiredAt == null ? '未返回' : expiredAt.toLocal().format()),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.data_usage_rounded),
          title: const Text('剩余流量'),
          subtitle: Text(remaining == null ? '未返回' : '${remaining.sizeGB()} / ${subscription.transferEnable.sizeGB()}'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.link_rounded),
          title: const Text('订阅链接'),
          subtitle: SelectableText(subscription.subscribeUrl, maxLines: 3),
          trailing: IconButton(
            tooltip: '复制',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => Clipboard.setData(ClipboardData(text: subscription.subscribeUrl)),
          ),
        ),
      ],
    );
  }
}
