import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/desktop_membership_page.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/utils/platform_utils.dart';
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
      appBar: showingLogin
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              leading: const _MobileProfileBackButton(),
              toolbarHeight: 72,
              title: const Text('我的账号'),
              titleTextStyle: BrandText.pageTitle,
            ),
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

class _MobileProfileBackButton extends StatelessWidget {
  const _MobileProfileBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed('home');
        }
      },
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
    );
  }
}

class UserSecurityCenterPage extends HookConsumerWidget {
  const UserSecurityCenterPage({super.key});

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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const _MobileProfileBackButton(),
        toolbarHeight: 72,
        title: const Text('安全中心'),
        titleTextStyle: BrandText.pageTitle,
      ),
      body: BrandScaffoldBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _SecurityCenterContent(authState: authState, errorText: authState.readableError(t)),
          ),
        ),
      ),
    );
  }
}

class _SecurityCenterContent extends StatelessWidget {
  const _SecurityCenterContent({required this.authState, required this.errorText});

  final AsyncValue<AuthState> authState;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final currentState = authState.valueOrNull;
    if (currentState?.isInitializing == true || (authState.isLoading && currentState == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    final session = currentState?.session;
    if (session == null) {
      return _SecurityLoggedOutContent(errorText: errorText);
    }

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SecurityIntroCard(session: session),
            const Gap(16),
            const _PasswordChangeCard(),
            const Gap(16),
            _PhoneBindCard(session: session),
          ],
        ),
      ),
    );
  }
}

class _SecurityLoggedOutContent extends StatelessWidget {
  const _SecurityLoggedOutContent({required this.errorText});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 54, color: BrandColors.signalBlue),
            const Gap(16),
            const Text('请先登录账号', style: BrandText.sectionTitle),
            const Gap(8),
            Text(
              errorText ?? '登录后可修改密码、绑定或更换手机号。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Gap(20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _GradientButton(onPressed: () => context.goNamed('settings'), label: '去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityIntroCard extends StatelessWidget {
  const _SecurityIntroCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final boundPhone = session.phone?.trim();
    return _PremiumCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.signalBlue.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: BrandColors.signalBlue, size: 22),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('账号安全', style: BrandText.sectionTitle),
                    const Gap(4),
                    Text(
                      boundPhone == null || boundPhone.isEmpty ? '建议绑定手机号，方便找回密码。' : '已绑定手机号：$boundPhone',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
  bool _showExternalError = true;

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
    final account = _emailController.text.trim();
    final password = _passwordController.text;
    final nextEmailError = account.isEmpty
        ? '请输入邮箱或手机号'
        : !_looksLikeLoginAccount(account)
        ? '邮箱或手机号格式不正确'
        : null;
    final nextPasswordError = password.isEmpty ? '请输入密码' : null;
    _emailError.value = nextEmailError;
    _passwordError.value = nextPasswordError;
    return nextEmailError == null && nextPasswordError == null;
  }

  void _clearEmailError() {
    if (_showExternalError) {
      setState(() => _showExternalError = false);
    }
    if (_emailError.value != null) {
      _emailError.value = null;
    }
  }

  void _clearPasswordError() {
    if (_showExternalError) {
      setState(() => _showExternalError = false);
    }
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
                  const Text('蝴蝶VPN', style: BrandText.brandTitle),
                  const Gap(8),
                  Text('安全、极速、无界', style: theme.textTheme.bodyMedium),
                  const Gap(48),
                  if (_showExternalError && widget.errorText != null) ...[
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
                          hintText: '邮箱 / 手机号',
                          errorText: errorText,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
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
                  const Gap(12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : () => context.pushNamed('authRegister'),
                        child: const Text('注册账号'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: isLoading ? null : () => context.pushNamed('authForgotPassword'),
                        child: const Text('忘记密码'),
                      ),
                    ],
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
            BoxShadow(color: BrandColors.signalBlue.withOpacity(.15), blurRadius: 30, offset: const Offset(0, 10)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final contentWidth = (width - 48).clamp(280.0, 680.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroMemberCard(session: session, subscription: subscription),
                    const Gap(18),
                    _SecurityCenterEntryCard(session: session),
                    const Gap(16),
                    _SupportCard(subscription: subscription),
                    const Gap(16),
                    _LogoutButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final planName = _displayText(subscription?.planName);
    final expiredAt = subscription?.expiredAt;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2D3E), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: BrandColors.slate.withOpacity(.26), blurRadius: 22, offset: const Offset(0, 12))],
      ),
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
                            _maskAccount(session.email),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BrandText.sectionTitle.copyWith(color: Colors.white, fontSize: 17),
                          ),
                          const Gap(4),
                          Text(
                            '设备：${_formatDeviceLimit(subscription)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              _PlanBadge(label: planName),
            ],
          ),
          const Gap(32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _MemberField(label: '到期时间', value: _formatExpiredAt(expiredAt), dark: true),
              ),
              const Gap(12),
              _SmallLightButton(label: '续费', onTap: () => context.pushNamed('premiumRenewal')),
              const Gap(8),
              _SmallLightButton(label: '升级', onTap: () => context.pushNamed('premiumRenewal')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

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
            label == '--' ? '蝴蝶VPN Pro' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BrandText.caption.copyWith(color: const Color(0xFF5C4000), fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SecurityCenterEntryCard extends StatelessWidget {
  const _SecurityCenterEntryCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final phone = session.phone?.trim();
    return _PremiumCard(
      children: [
        _ActionTile(
          icon: Icons.admin_panel_settings_rounded,
          title: '安全中心',
          subtitle: phone == null || phone.isEmpty ? '修改密码 / 绑定手机号' : '修改密码 / 更换手机号',
          iconColor: BrandColors.signalBlue,
          onTap: () => context.pushNamed('securityCenter'),
        ),
      ],
    );
  }
}

class _PasswordChangeCard extends ConsumerStatefulWidget {
  const _PasswordChangeCard();

  @override
  ConsumerState<_PasswordChangeCard> createState() => _PasswordChangeCardState();
}

class _PasswordChangeCardState extends ConsumerState<_PasswordChangeCard> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
          .changePassword(oldPassword: _oldPasswordController.text, newPassword: _newPasswordController.text);
      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (error) {
      if (mounted) setState(() => _errorText = _presentError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validate() {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    if (oldPassword.isEmpty) return '请输入原密码';
    if (newPassword.length < 8) return '新密码至少 8 位';
    if (newPassword == oldPassword) return '新密码不能和原密码相同';
    if (newPassword != _confirmPasswordController.text) return '两次输入的新密码不一致';
    return null;
  }

  String _presentError(Object error) {
    final t = ref.read(translationsProvider).requireValue;
    final pair = t.presentError(error);
    final message = pair.message?.trim();
    return message == null || message.isEmpty ? pair.type : '${pair.type}\n$message';
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: BrandColors.signalBlue, size: 20),
                  Gap(10),
                  Expanded(child: Text('修改密码', style: BrandText.sectionTitle)),
                ],
              ),
              const Gap(6),
              Text('定期更新登录密码，保护账号和订阅安全。', style: Theme.of(context).textTheme.bodySmall),
              const Gap(14),
              if (_errorText != null) ...[
                Text(_errorText!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandColors.error)),
                const Gap(10),
              ],
              TextField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), hintText: '原密码'),
              ),
              const Gap(10),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset_rounded), hintText: '新密码'),
              ),
              const Gap(10),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.verified_user_outlined), hintText: '确认新密码'),
                onSubmitted: (_) => _submit(),
              ),
              const Gap(12),
              _GradientButton(
                label: _submitting ? '修改中' : '修改密码',
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneBindCard extends ConsumerStatefulWidget {
  const _PhoneBindCard({required this.session});

  final AuthSession session;

  @override
  ConsumerState<_PhoneBindCard> createState() => _PhoneBindCardState();
}

class _PhoneBindCardState extends ConsumerState<_PhoneBindCard> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _sendingCode = false;
  bool _binding = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.session.phone ?? '';
  }

  @override
  void didUpdateWidget(covariant _PhoneBindCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.phone != widget.session.phone && _codeController.text.isEmpty) {
      _phoneController.text = widget.session.phone ?? '';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!_looksLikeLoginAccount(phone) || phone.contains('@')) {
      setState(() => _errorText = '请输入正确的手机号');
      return;
    }
    if (_sendingCode) return;
    setState(() {
      _sendingCode = true;
      _errorText = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).sendPhoneBindVerify(phone);
    } catch (error) {
      setState(() => _errorText = _presentError(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _bindPhone() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (!_looksLikeLoginAccount(phone) || phone.contains('@')) {
      setState(() => _errorText = '请输入正确的手机号');
      return;
    }
    if (code.isEmpty) {
      setState(() => _errorText = '请输入手机验证码');
      return;
    }
    if (_binding) return;
    setState(() {
      _binding = true;
      _errorText = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).bindPhone(phone: phone, phoneCode: code);
      if (mounted) _codeController.clear();
    } catch (error) {
      setState(() => _errorText = _presentError(error));
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  String _presentError(Object error) {
    final t = ref.read(translationsProvider).requireValue;
    final pair = t.presentError(error);
    final message = pair.message?.trim();
    return message == null || message.isEmpty ? pair.type : '${pair.type}\n$message';
  }

  @override
  Widget build(BuildContext context) {
    final currentPhone = widget.session.phone?.trim();
    final isBound = currentPhone != null && currentPhone.isNotEmpty;
    return _PremiumCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, color: BrandColors.signalBlue, size: 20),
                  const Gap(10),
                  Expanded(child: Text(isBound ? '已绑定手机号：$currentPhone' : '绑定手机号', style: BrandText.sectionTitle)),
                ],
              ),
              const Gap(6),
              Text('登录成功后绑定手机号，绑定后可使用邮箱或手机号登录。', style: Theme.of(context).textTheme.bodySmall),
              const Gap(14),
              if (_errorText != null) ...[
                Text(_errorText!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandColors.error)),
                const Gap(10),
              ],
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_iphone_rounded), hintText: '请输入手机号'),
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.verified_outlined), hintText: '手机验证码'),
                    ),
                  ),
                  const Gap(10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _sendingCode ? null : _sendCode,
                      child: Text(_sendingCode ? '发送中' : '验证码'),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              _GradientButton(
                label: _binding
                    ? '绑定中'
                    : isBound
                    ? '更换手机号'
                    : '绑定手机号',
                isLoading: _binding,
                onPressed: _binding ? null : _bindPhone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberField extends StatelessWidget {
  const _MemberField({required this.label, required this.value, this.dark = false});

  final String label;
  final String value;
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
          style: BrandText.sectionTitle.copyWith(color: dark ? Colors.white : BrandColors.slate),
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
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.14)),
        ),
        child: Text(label, style: BrandText.smallButton.copyWith(color: const Color(0xFFFFD700))),
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

String _maskAccount(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '--';
  final at = trimmed.indexOf('@');
  if (at <= 1) return '${trimmed.substring(0, 1)}***';
  return '${trimmed.substring(0, 1)}***${trimmed.substring(at)}';
}

class _SupportCard extends HookConsumerWidget {
  const _SupportCard({required this.subscription});

  final UserSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PremiumCard(
      children: [
        _ActionTile(
          icon: Icons.support_agent_rounded,
          title: '联系客服',
          iconColor: const Color(0xFF2563EB),
          onTap: () => context.pushNamed('premiumContact'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.card_giftcard_rounded,
          title: '邀请有礼',
          subtitle: '邀请好友得免费时长',
          iconColor: const Color(0xFFFF9500),
          onTap: () => context.pushNamed('premiumInvite'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.feedback_outlined,
          title: '反馈问题',
          iconColor: const Color(0xFF2563EB),
          onTap: () => context.pushNamed('premiumFeedback'),
        ),
        const _ActionDivider(),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: '关于 蝴蝶VPN',
          iconColor: const Color(0xFF64748B),
          onTap: () => context.pushNamed('premiumAbout'),
        ),
      ],
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 24, color: Color(0xFFF5F7FA));
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.iconColor, this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: BrandText.sectionTitle),
      subtitle: subtitle == null ? null : Text(subtitle!, style: BrandText.caption),
      trailing: const Icon(Icons.chevron_right_rounded, color: BrandColors.subtle),
      onTap: onTap,
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return TextButton(
      onPressed: isLoading ? null : () => ref.read(authNotifierProvider.notifier).logout(),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: BrandColors.error.withOpacity(.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text('退出登录', style: BrandText.buttonLabel.copyWith(color: BrandColors.error)),
    );
  }
}

String _formatExpiredAt(DateTime? expiredAt) {
  if (expiredAt == null) return '--';
  return DateFormat('yyyy/MM/dd HH:mm').format(expiredAt.toLocal());
}

bool _looksLikeLoginAccount(String value) {
  final trimmed = value.trim();
  if (trimmed.contains('@')) return trimmed.contains('.');
  return RegExp(r'^\+?[0-9][0-9\s\-()]{5,30}$').hasMatch(trimmed);
}
