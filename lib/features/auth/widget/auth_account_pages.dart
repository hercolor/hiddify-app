import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
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
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _sendingCode = false;
  bool _submitting = false;
  bool _acceptedTerms = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _errorText = '请先输入正确的邮箱');
      return;
    }
    if (_sendingCode) return;
    setState(() {
      _sendingCode = true;
      _errorText = null;
    });
    try {
      final service = await ref.read(loginServiceProvider.future);
      await service.sendEmailVerify(account: email).match((err) => throw err, (_) {}).run();
      ref.read(inAppNotificationControllerProvider).showSuccessToast('验证码已发送');
    } catch (error) {
      setState(() => _errorText = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            phone: _emptyToNull(_phoneController.text),
            password: _passwordController.text,
            emailCode: _emptyToNull(_codeController.text),
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
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (!_looksLikeEmail(email)) return '请输入正确的邮箱';
    if (phone.isNotEmpty && !_looksLikePhone(phone)) return '手机号格式不正确';
    if (password.length < 8) return '密码至少 8 位';
    if (password != _confirmPasswordController.text) return '两次输入的密码不一致';
    if (!_acceptedTerms) return '请先同意用户协议和隐私政策';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormScaffold(
      title: '注册账号',
      subtitle: '创建 4376 账号后自动完成加速准备',
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
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              hintText: '手机号（可选，用于手机号登录）',
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.verified_outlined),
                    hintText: '邮箱验证码（按后台配置填写）',
                  ),
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
          CheckboxListTile(
            value: _acceptedTerms,
            onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
            contentPadding: EdgeInsets.zero,
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('我已阅读并同意'),
                TextButton(onPressed: () => context.pushNamed('termsOfService'), child: const Text('用户协议')),
                const Text('和'),
                TextButton(onPressed: () => context.pushNamed('privacyPolicy'), child: const Text('隐私政策')),
              ],
            ),
          ),
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
      await service.sendEmailVerify(account: account).match((err) => throw err, (_) {}).run();
      ref.read(inAppNotificationControllerProvider).showSuccessToast('验证码已发送到绑定邮箱');
    } catch (error) {
      setState(() => _errorText = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final service = await ref.read(loginServiceProvider.future);
      await service
          .resetPassword(
            account: _accountController.text.trim(),
            emailCode: _codeController.text.trim(),
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
  const _AuthFormScaffold({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 64),
              const Gap(18),
              Text(title, style: PlatformUtils.isDesktop ? BrandDesktopText.pageTitle : BrandText.pageTitle),
              const Gap(6),
              Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const Gap(26),
              child,
            ],
          ),
        ),
      ),
    );

    if (PlatformUtils.isDesktop) {
      return DesktopTheme(
        child: DesktopPageScaffold(title: title, subtitle: subtitle, leading: const DesktopBackButton(), child: form),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: form,
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
      child: ElevatedButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
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
