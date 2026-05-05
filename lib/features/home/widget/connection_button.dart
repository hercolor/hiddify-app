import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
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
          ? BrandColors.success
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
        phase == ClientConnectionPhase.reconnecting;
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child:
              Container(
                    width: 188,
                    height: 188,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withValues(alpha: connected ? .24 : .16),
                          accentColor.withValues(alpha: .07),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: connected ? BrandGradients.connected : BrandGradients.primary,
                          boxShadow: BrandShadows.glow(accentColor, alpha: enabled ? .22 : .08),
                        ),
                        child: Material(
                          key: const ValueKey("home_connection_button"),
                          shape: const CircleBorder(),
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: enabled ? onTap : null,
                            child: Center(
                              child: busy
                                  ? const SizedBox.square(
                                      dimension: 36,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const BrandMark(size: 62, showWordmark: false, dark: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate(target: animated ? 1 : 0)
                  .scaleXY(end: 1.035, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut)
                  .then()
                  .scaleXY(end: .966, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut)
                  .animate(target: enabled ? 0 : 1)
                  .scaleXY(end: .92, curve: Curves.easeIn),
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
