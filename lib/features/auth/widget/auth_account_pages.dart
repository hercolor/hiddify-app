import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AuthRegisterPage extends ConsumerStatefulWidget {
  const AuthRegisterPage({super.key});

  @override
  ConsumerState<AuthRegisterPage> createState() => _AuthRegisterPageState();
}

class _AuthRegisterPageState extends ConsumerState<AuthRegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _submitting = false;
  bool _acceptedTerms = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_acceptedTerms) {
      final accepted = await _confirmTermsAcceptance();
      if (accepted != true) return;
      if (!mounted) return;
      setState(() => _acceptedTerms = true);
    }

    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            inviteCode: _emptyToNull(_inviteCodeController.text),
          );
      final authState = ref.read(authNotifierProvider);
      if (authState case AsyncError(:final error)) {
        setState(() => _errorText = _authErrorMessage(error));
        return;
      }
      if (authState.valueOrNull?.isLoggedIn == true && mounted) {
        context.goNamed('home');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_looksLikeEmail(email)) return '请输入正确的邮箱';
    if (password.length < 8) return '密码至少 8 位';
    if (password != _confirmPasswordController.text) return '两次输入的密码不一致';
    return null;
  }

  Future<bool?> _confirmTermsAcceptance() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('请确认协议'),
        content: const Text('注册前需要阅读并同意《用户协议》和《隐私政策》。点击确定后将自动勾选并继续注册。'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormScaffold(
      title: '注册账号',
      subtitle: '创建 BflyVPN 账号后自动完成加速准备',
      showHeader: false,
      child: Column(
        children: [
          if (_errorText != null) ...[_ErrorBanner(_errorText!), const Gap(14)],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), hintText: '邮箱'),
          ),
          const Gap(12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), hintText: '密码'),
          ),
          const Gap(12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset_rounded), hintText: '确认密码'),
          ),
          const Gap(12),
          TextField(
            controller: _inviteCodeController,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.card_giftcard_rounded), hintText: '邀请码（如需要）'),
          ),
          const Gap(12),
          _TermsAgreementRow(accepted: _acceptedTerms, onChanged: (value) => setState(() => _acceptedTerms = value)),
          const Gap(18),
          _PrimaryAuthButton(label: '注册并登录', isLoading: _submitting, onPressed: _submitting ? null : _submit),
          const Gap(12),
          TextButton(onPressed: () => context.pop(), child: const Text('已有账号，返回登录')),
        ],
      ),
    );
  }
}

class AuthForgotPasswordPage extends ConsumerStatefulWidget {
  const AuthForgotPasswordPage({super.key});

  @override
  ConsumerState<AuthForgotPasswordPage> createState() => _AuthForgotPasswordPageState();
}

class _AuthForgotPasswordPageState extends ConsumerState<AuthForgotPasswordPage> {
  final _accountController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _sendingCode = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _accountController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailCode() async {
    final account = _accountController.text.trim();
    if (!_looksLikeAccount(account)) {
      setState(() => _errorText = '请先输入正确的邮箱或手机号');
      return;
    }
    if (_sendingCode) return;
    setState(() {
      _sendingCode = true;
      _errorText = null;
    });
    try {
      final service = await ref.read(loginServiceProvider.future);
      if (_looksLikeEmail(account)) {
        await service.sendEmailVerify(account: account).match((err) => throw err, (_) {}).run();
        ref.read(inAppNotificationControllerProvider).showSuccessToast('验证码已发送到绑定邮箱');
      } else {
        await service.sendPhoneVerify(account: account).match((err) => throw err, (_) {}).run();
        ref.read(inAppNotificationControllerProvider).showSuccessToast('验证码已发送到绑定手机');
      }
    } catch (error) {
      setState(() => _errorText = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final service = await ref.read(loginServiceProvider.future);
      await service
          .resetPassword(
            account: _accountController.text.trim(),
            verifyCode: _codeController.text.trim(),
            password: _passwordController.text,
          )
          .match((err) => throw err, (_) {})
          .run();
      ref.read(inAppNotificationControllerProvider).showSuccessToast('密码已重置，请重新登录');
      if (mounted) context.pop();
    } catch (error) {
      setState(() => _errorText = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validate() {
    if (!_looksLikeAccount(_accountController.text.trim())) return '请输入正确的邮箱或手机号';
    if (_codeController.text.trim().isEmpty) return '请输入验证码';
    final password = _passwordController.text;
    if (password.length < 8) return '密码至少 8 位';
    if (password != _confirmPasswordController.text) return '两次输入的密码不一致';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormScaffold(
      title: '忘记密码',
      subtitle: '通过账号绑定邮箱验证码重置密码',
      showHeader: false,
      child: Column(
        children: [
          if (_errorText != null) ...[_ErrorBanner(_errorText!), const Gap(14)],
          TextField(
            controller: _accountController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), hintText: '邮箱 / 手机号'),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.verified_outlined), hintText: '验证码'),
                ),
              ),
              const Gap(10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _sendingCode ? null : _sendEmailCode,
                  child: Text(_sendingCode ? '发送中' : '获取验证码'),
                ),
              ),
            ],
          ),
          const Gap(12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), hintText: '新密码'),
          ),
          const Gap(12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset_rounded), hintText: '确认新密码'),
          ),
          const Gap(22),
          _PrimaryAuthButton(label: '重置密码', isLoading: _submitting, onPressed: _submitting ? null : _submit),
          const Gap(12),
          TextButton(onPressed: () => context.pop(), child: const Text('返回登录')),
        ],
      ),
    );
  }
}

class _AuthFormScaffold extends StatelessWidget {
  const _AuthFormScaffold({required this.title, required this.subtitle, required this.child, this.showHeader = true});

  final String title;
  final String subtitle;
  final Widget child;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, showHeader ? 24 : 18, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader) ...[
              Image.asset('assets/images/app_icon.png', width: 80, height: 80),
              const Gap(18),
              Text(title, style: PlatformUtils.isDesktop ? BrandDesktopText.pageTitle : BrandText.pageTitle),
              const Gap(6),
              Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const Gap(26),
            ],
            child,
          ],
        ),
      ),
    );
    final form = Align(alignment: showHeader ? Alignment.center : Alignment.topCenter, child: content);

    if (PlatformUtils.isDesktop) {
      if (!showHeader) {
        return DesktopTheme(
          child: DesktopBackdrop(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(left: 20, top: 18, child: DesktopBackButton(onPressed: () => _goBackToLogin(context))),
                  Padding(padding: const EdgeInsets.only(top: 46), child: form),
                ],
              ),
            ),
          ),
        );
      }
      return DesktopTheme(
        child: DesktopPageScaffold(title: title, subtitle: subtitle, leading: const DesktopBackButton(), child: form),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: showHeader ? Text(title) : null,
        leading: showHeader
            ? null
            : IconButton(
                onPressed: () => _goBackToLogin(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
      ),
      body: SafeArea(child: form),
    );
  }
}

void _goBackToLogin(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed('membership');
  }
}

class _TermsAgreementRow extends StatelessWidget {
  const _TermsAgreementRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
    );
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.25);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!accepted),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Checkbox(
                value: accepted,
                onChanged: (value) => onChanged(value ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Gap(4),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                children: [
                  Text('我已阅读并同意', style: textStyle),
                  TextButton(
                    style: linkStyle,
                    onPressed: () => context.pushNamed('termsOfService'),
                    child: const Text('用户协议'),
                  ),
                  Text('和', style: textStyle),
                  TextButton(
                    style: linkStyle,
                    onPressed: () => context.pushNamed('privacyPolicy'),
                    child: const Text('隐私政策'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({required this.label, required this.isLoading, required this.onPressed});

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isDesktop) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: DesktopGradientButton(label: label, isLoading: isLoading, onPressed: onPressed),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _MobileGradientButton(label: label, isLoading: isLoading, onPressed: onPressed),
    );
  }
}

class _MobileGradientButton extends StatelessWidget {
  const _MobileGradientButton({required this.label, required this.isLoading, required this.onPressed});

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onPressed == null
                  ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                  : [const Color(0xFF0EA5E9), const Color(0xFF0284C7), const Color(0xFF0369A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: onPressed != null
                ? [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withOpacity(.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : Text(
                    label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: BrandColors.error.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandColors.error),
      ),
    );
  }
}

bool _looksLikeEmail(String value) => value.contains('@') && value.contains('.');

bool _looksLikePhone(String value) => RegExp(r'^\+?[0-9][0-9\s\-()]{5,30}$').hasMatch(value);

bool _looksLikeAccount(String value) => _looksLikeEmail(value) || _looksLikePhone(value);

String? _emptyToNull(String text) {
  final value = text.trim();
  return value.isEmpty ? null : value;
}

String _authErrorMessage(Object error) {
  if (error is AuthServerMessageFailure) return error.message;
  if (error is AuthInvalidCredentialsFailure) return error.message ?? '账号或密码不正确';
  if (error is AuthTokenExpiredFailure) return error.message ?? '登录已过期，请重新登录';
  if (error is AuthNetworkFailure) return error.message ?? '网络连接失败，请稍后重试';
  if (error is AuthBadResponseFailure) return error.message ?? '服务器返回异常';
  if (error is AuthNotLoggedInFailure) return '请先登录账号';
  return '操作失败，请稍后重试';
}
