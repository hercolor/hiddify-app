import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/user_profile_page.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/utils/platform_utils.dart';
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
      return const Center(child: CircularProgressIndicator());
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
  String? _loginError;
  bool _isSubmitting = false;
  bool _showExternalError = true;

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
    setState(() {
      _isSubmitting = true;
      _loginError = null;
    });
    DiagnosticEventBuffer.addSafe('loginRequestStart');
    try {
      await ref.read(authNotifierProvider.notifier).login(_emailController.text, _passwordController.text);
      stopwatch.stop();
      final authState = ref.read(authNotifierProvider);
      final loggedIn = authState.valueOrNull?.isLoggedIn == true;
      DiagnosticEventBuffer.addSafe('loginRequestEnd success=$loggedIn elapsedMs=${stopwatch.elapsedMilliseconds}');
      if (!mounted) return;
      if (loggedIn) {
        context.goNamed('home');
      } else if (authState case AsyncError(:final error)) {
        setState(() {
          _loginError = _authErrorMessage(error);
          _showExternalError = true;
        });
      } else {
        // 登录既没有成功也没有报错，显示当前状态帮助排查
        setState(() {
          _loginError = '登录未成功，当前状态：${authState.valueOrNull?.status.name ?? "未知"}，请检查网络连接后重试';
          _showExternalError = true;
        });
      }
    } catch (error) {
      stopwatch.stop();
      DiagnosticEventBuffer.addSafe('loginRequestException: $error');
      if (mounted) {
        setState(() {
          _loginError = '登录过程出错：${_authErrorMessage(error)}';
          _showExternalError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validate() {
    final account = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = account.isEmpty
          ? '请输入邮箱或手机号'
          : !_looksLikeLoginAccount(account)
          ? '邮箱或手机号格式不正确'
          : null;
      _passwordError = password.isEmpty ? '请输入密码' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  void _clearExternalError() {
    if (_showExternalError) {
      setState(() => _showExternalError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopTheme(
      child: DesktopBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 326),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _DesktopLoginMark(),
                        const Gap(24),
                        Transform.translate(
                          offset: const Offset(-2, 0),
                          child: Image.asset(
                            'assets/images/logo_text.png',
                            width: 220,
                            height: 55,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Gap(8),
                        Text('Fast, Secure, Borderless', style: Theme.of(context).textTheme.bodyMedium),
                        const Gap(42),
                        if (_loginError != null) ...[
                          Text(
                            _loginError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.error),
                          ),
                          const Gap(14),
                        ] else if (_showExternalError && widget.errorText != null) ...[
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
                            hintText: '邮箱 / 手机号',
                            errorText: _emailError,
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            _clearExternalError();
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
                            _clearExternalError();
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
                        const Gap(12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _isSubmitting ? null : () => context.pushNamed('authRegister'),
                              child: const Text('注册账号'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _isSubmitting ? null : () => context.pushNamed('authForgotPassword'),
                              child: const Text('忘记密码'),
                            ),
                          ],
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
            ],
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
    return RepaintBoundary(child: Image.asset('assets/images/app_icon.png', width: 100, height: 100));
  }
}

class _DesktopMemberCenter extends StatelessWidget {
  const _DesktopMemberCenter({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final subscription = session.subscription;
    final plan = _PlanCard(session: session, subscription: subscription);
    final traffic = subscription != null && subscription.hasTrafficInfo
        ? _TrafficCard(subscription: subscription)
        : null;
    final security = _SecurityCenterCard(session: session);
    const actions = _MemberActions();

    return DesktopTheme(
      child: DesktopBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: Column(
              children: [
                const Gap(10),
                const Center(child: Text('我的账号', style: BrandDesktopText.pageTitle)),
                const Gap(12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              plan,
                              const Gap(18),
                              if (traffic != null) ...[traffic, const Gap(18)],
                              security,
                              const Gap(18),
                              actions,
                              const Gap(16),
                              const _DesktopLogoutButton(),
                              const Gap(20),
                            ],
                          ),
                        ),
                      );
                    },
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

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.session, required this.subscription});

  final AuthSession session;
  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planName = _displayText(subscription?.planName);
    return DesktopCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFF38BDF8).withOpacity(.3),
      padding: const EdgeInsets.all(22),
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
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withOpacity(.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
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
                            style: BrandDesktopText.sectionTitle.copyWith(color: Colors.white, fontSize: 15),
                          ),
                          const Gap(4),
                          Text(
                            '设备：${_formatDeviceLimit(subscription)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFBAE6FD)),
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
          const Gap(36),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE), Color(0xFFBAE6FD)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(.12), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFF0369A1)),
          const Gap(5),
          Text(
            label == '--' ? 'BflyVPN Pro' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BrandDesktopText.bodyPrimary.copyWith(
              color: const Color(0xFF0369A1),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
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
          style: BrandDesktopText.sectionTitle.copyWith(color: dark ? Colors.white : BrandDesktopColors.textPrimary),
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
      minimumSize: const WidgetStatePropertyAll(Size(56, 36)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      backgroundColor: WidgetStatePropertyAll(Colors.white.withOpacity(.22)),
      side: WidgetStatePropertyAll(BorderSide(color: Colors.white.withOpacity(.2))),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
    final child = Text(label, style: BrandDesktopText.smallButton);
    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _SecurityCenterCard extends StatelessWidget {
  const _SecurityCenterCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final phone = session.phone?.trim();
    final isMobile = PlatformUtils.isAndroid;
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMobile) ...[
            _ActionRow(
              icon: Icons.lock_reset_rounded,
              title: '修改密码',
              subtitle: '更新账号登录密码',
              iconColor: BrandDesktopColors.accent,
              onTap: () => showSecurityActionModal(
                context,
                title: '修改密码',
                child: const PasswordChangeCard(closeOnSuccess: true),
              ),
            ),
            const _DesktopActionDivider(),
            _ActionRow(
              icon: Icons.phone_iphone_rounded,
              title: '绑定手机',
              subtitle: phone == null || phone.isEmpty ? '绑定后可使用手机号登录和找回密码' : '当前手机号：$phone',
              iconColor: const Color(0xFF10B981),
              onTap: () => showSecurityActionModal(
                context,
                title: '绑定手机',
                child: PhoneBindCard(session: session, closeOnSuccess: true),
              ),
            ),
            const _DesktopActionDivider(),
          ] else
            _ActionRow(
              icon: Icons.lock_reset_rounded,
              title: '修改密码',
              subtitle: '更新账号登录密码',
              iconColor: BrandDesktopColors.accent,
              onTap: () => showSecurityActionModal(
                context,
                title: '修改密码',
                child: const PasswordChangeCard(closeOnSuccess: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberActions extends StatelessWidget {
  const _MemberActions();

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionRow(
            icon: Icons.support_agent_rounded,
            title: '联系客服',
            iconColor: const Color(0xFF2563EB),
            onTap: () => context.pushNamed('premiumContact'),
          ),
          const _DesktopActionDivider(),
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
            icon: Icons.info_outline_rounded,
            title: '关于 BflyVPN',
            iconColor: const Color(0xFF64748B),
            onTap: () => context.pushNamed('premiumAbout'),
          ),
        ],
      ),
    );
  }
}

class _DesktopActionDivider extends StatelessWidget {
  const _DesktopActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF1F5F9));
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor.withOpacity(.15)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: BrandDesktopText.sectionTitle.copyWith(fontSize: 14)),
                    if (subtitle != null) ...[
                      const Gap(3),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_right_rounded, color: BrandDesktopColors.textMuted, size: 16),
              ),
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
      onPressed: isLoading
          ? null
          : () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.goNamed('membership');
            },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        backgroundColor: BrandDesktopColors.error.withOpacity(.06),
        foregroundColor: BrandDesktopColors.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: BrandDesktopColors.error.withOpacity(.15)),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 18),
          SizedBox(width: 8),
          Text(
            '退出登录',
            style: TextStyle(color: BrandDesktopColors.error, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.subscription});

  final UserSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final used = subscription.usedTraffic;
    final remaining = subscription.remainingTraffic ?? 0;
    final total = subscription.transferEnable;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final isExhausted = subscription.isTrafficExhausted;

    return DesktopCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('流量使用', style: BrandDesktopText.sectionTitle),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExhausted
                      ? BrandDesktopColors.error.withOpacity(.08)
                      : BrandDesktopColors.accent.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isExhausted
                        ? BrandDesktopColors.error.withOpacity(.15)
                        : BrandDesktopColors.accent.withOpacity(.15),
                  ),
                ),
                child: Text(
                  isExhausted ? '已用尽' : '${(ratio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isExhausted ? BrandDesktopColors.error : BrandDesktopColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(isExhausted ? BrandDesktopColors.error : BrandDesktopColors.accent),
            ),
          ),
          const Gap(16),
          Row(
            children: [
              Expanded(
                child: _TrafficField(
                  icon: Icons.cloud_download_rounded,
                  label: '已使用',
                  value: _formatBytes(used),
                  color: isExhausted ? BrandDesktopColors.error : const Color(0xFF0F172A),
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _TrafficField(
                  icon: Icons.data_usage_rounded,
                  label: '剩余',
                  value: isExhausted ? '0 GB' : _formatBytes(remaining),
                  color: isExhausted ? BrandDesktopColors.textMuted : BrandDesktopColors.success,
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _TrafficField(
                  icon: Icons.all_inclusive_rounded,
                  label: '总量',
                  value: _formatBytes(total),
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 GB';
  final gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

class _TrafficField extends StatelessWidget {
  const _TrafficField({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color.withOpacity(.6)),
              const Gap(3),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BrandDesktopColors.textMuted),
              ),
            ],
          ),
          const Gap(4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

String _formatDeviceLimit(UserSubscription? subscription) {
  final max = subscription?.maxDevices;
  if (max == null || max <= 0) return '--';
  return '最多 $max 台';
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

bool _looksLikeLoginAccount(String value) {
  final trimmed = value.trim();
  if (trimmed.contains('@')) return trimmed.contains('.');
  return RegExp(r'^\+?[0-9][0-9\s\-()]{5,30}$').hasMatch(trimmed);
}

String _authErrorMessage(Object error) {
  if (error is AuthServerMessageFailure) return error.message;
  if (error is AuthInvalidCredentialsFailure) return error.message ?? '账号或密码不正确';
  if (error is AuthTokenExpiredFailure) return error.message ?? '登录已过期，请重新登录';
  if (error is AuthNetworkFailure) return error.message ?? '网络连接失败，请稍后重试';
  if (error is AuthBadResponseFailure) return error.message ?? '服务器返回异常';
  if (error is AuthNotLoggedInFailure) return '请先登录账号';
  final raw = error.toString();
  return raw.length <= 120 ? raw : '${raw.substring(0, 120)}…';
}
