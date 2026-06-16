import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/actions_at_closing.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/features/window/notifier/window_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class WindowClosingDialog extends ConsumerStatefulWidget {
  const WindowClosingDialog({super.key});

  @override
  ConsumerState<WindowClosingDialog> createState() => _WindowClosingDialogState();
}

class _WindowClosingDialogState extends ConsumerState<WindowClosingDialog> {
  bool remember = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: BrandDesktopColors.border),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withOpacity(.18), blurRadius: 32, offset: const Offset(0, 18)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: BrandDesktopGradients.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 24),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('关闭蝴蝶加速？', style: BrandDesktopText.sectionTitle.copyWith(fontSize: 18)),
                          const Gap(4),
                          Text(
                            '可以最小化到托盘继续运行，或完全退出应用。',
                            style: theme.textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(22),
                _CloseChoiceButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  title: t.common.hide,
                  subtitle: '保持后台运行，托盘可重新打开',
                  highlighted: true,
                  onTap: _hideWindow,
                ),
                const Gap(10),
                _CloseChoiceButton(
                  icon: Icons.logout_rounded,
                  title: t.common.exit,
                  subtitle: '停止连接并退出程序',
                  highlighted: false,
                  onTap: _exitApp,
                ),
                const Gap(12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => remember = !remember),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: remember,
                          onChanged: (value) => setState(() => remember = value ?? remember),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            t.dialogs.windowClosing.remember,
                            style: theme.textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _hideWindow() async {
    if (remember) {
      await ref.read(Preferences.actionAtClose.notifier).update(ActionsAtClosing.hide);
    }
    if (mounted) Navigator.of(context).pop(false);
    await ref.read(windowNotifierProvider.notifier).hide();
  }

  Future<void> _exitApp() async {
    if (remember) {
      await ref.read(Preferences.actionAtClose.notifier).update(ActionsAtClosing.exit);
    }
    if (mounted) Navigator.of(context).pop(true);
    await ref.read(windowNotifierProvider.notifier).exit();
  }
}

class _CloseChoiceButton extends StatelessWidget {
  const _CloseChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? Colors.white : BrandDesktopColors.textPrimary;
    final subtitleColor = highlighted ? Colors.white.withOpacity(.78) : BrandDesktopColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: highlighted ? BrandDesktopGradients.primary : null,
            color: highlighted ? null : BrandDesktopColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: highlighted ? Colors.transparent : BrandDesktopColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: highlighted ? Colors.white.withOpacity(.18) : BrandDesktopColors.accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: highlighted ? Colors.white : BrandDesktopColors.accent, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const Gap(2),
                    Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subtitleColor),
            ],
          ),
        ),
      ),
    );
  }
}
