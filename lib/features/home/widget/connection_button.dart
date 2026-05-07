import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// TODO: rewrite
class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(clientConnectionStateProvider);
    // final animationController = useAnimationController(
    //   duration: const Duration(seconds: 1),
    // )..repeat(reverse: true); // Ensure the animation loops indefinitely

    //   // Listen to the animation's value
    //   final animationValue = useAnimation(Tween<double>(begin: 0.8, end: 1).animate(animationController));

    //   // useEffect(() {
    //   //   if (true) {
    //   // Start repeating animation
    //   //   } else {
    //   //     animationController.stop(); // Stop animation if connected, disconnected, or error
    //   //   }

    //   //   // Cleanup when widget is disposed
    //   //   return animationController.dispose;
    //   // }, [connectionStatus.value]);

    //   // ref.listen(
    //   //   connectionNotifierProvider,
    //   //   (_, next) {
    //   //     if (next case AsyncError(:final error)) {
    //   //       CustomAlertDialog.fromErr(t.presentError(error)).show(context);
    //   //     }
    //   //     if (next case AsyncData(value: Disconnected(:final connectionFailure?))) {
    //   //       CustomAlertDialog.fromErr(t.presentError(connectionFailure)).show(context);
    //   //     }
    //   //   },
    //   // );

    final enabled = clientState.canTap;
    final connected = clientState.phase == ClientConnectionPhase.connected;
    final busy = clientState.isBusy;
    final failed = clientState.phase == ClientConnectionPhase.failed;
    final loggedOut = clientState.phase == ClientConnectionPhase.loggedOut;

    return _ConnectionButton(
      onTap: () async {
        if (clientState.phase == ClientConnectionPhase.loggedOut) {
          ref.read(connectionNotifierProvider.notifier).connectRequested();
          if (context.mounted) {
            context.goNamed('settings');
          }
          return;
        }
        await ref.read(connectionNotifierProvider.notifier).connectRequested();
      },
      enabled: enabled,
      label: clientState.buttonLabel,
      phase: clientState.phase,
      accentColor: connected
          ? BrandColors.signalBlue
          : failed
          ? BrandColors.error
          : busy
          ? BrandColors.warning
          : loggedOut
          ? BrandColors.subtle
          : BrandColors.signalBlue,
      animated: connected || busy,
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.phase,
    required this.accentColor,
    required this.animated,
  });

  final VoidCallback? onTap;
  final bool enabled;
  final String label;
  final ClientConnectionPhase phase;
  final Color accentColor;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final connected = phase == ClientConnectionPhase.connected;
    final busy =
        phase == ClientConnectionPhase.connecting ||
        phase == ClientConnectionPhase.preparing ||
        phase == ClientConnectionPhase.requestingVpnPermission ||
        phase == ClientConnectionPhase.reconnecting ||
        phase == ClientConnectionPhase.stopping;
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: AnimatedScale(
            scale: animated ? 1.03 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? BrandColors.signalBlue : BrandColors.card,
                border: Border.all(color: connected ? Colors.transparent : BrandColors.border),
                boxShadow: [
                  BoxShadow(
                    color: connected
                        ? BrandColors.signalBlue.withValues(alpha: .30)
                        : Colors.black.withValues(alpha: .05),
                    blurRadius: connected ? 32 : 16,
                    spreadRadius: connected ? 8 : 4,
                    offset: const Offset(0, 8),
                  ),
                  if (busy) BoxShadow(color: accentColor.withValues(alpha: .18), blurRadius: 44, spreadRadius: 10),
                ],
              ),
              child: Material(
                key: const ValueKey("home_connection_button"),
                shape: const CircleBorder(),
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? onTap : null,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: busy
                        ? SizedBox.square(
                            dimension: 36,
                            child: CircularProgressIndicator(color: accentColor, strokeWidth: 3),
                          )
                        : Icon(
                            connected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                            size: 64,
                            color: connected ? Colors.white : BrandColors.subtle,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Gap(18),
        ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText(
                label,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: BrandColors.slate),
              ),
              const Gap(6),
              Text(
                connected
                    ? '连接稳定，正在保护您的网络'
                    : busy
                    ? '正在建立安全连接'
                    : '轻触即可开启安全加速',
                style: theme.textTheme.bodySmall?.copyWith(color: BrandColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
