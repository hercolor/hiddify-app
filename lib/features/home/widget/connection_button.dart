import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// TODO: rewrite
class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectionNotifierProvider);
    final clientState = ref.watch(clientConnectionStateProvider);
    final today = DateTime.now();
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

    const buttonTheme = ConnectionButtonTheme.light;
    const secureLabel = "";
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
      buttonColor: connected
          ? buttonTheme.connectedColor!
          : failed
          ? Colors.red.shade700
          : busy
          ? const Color.fromARGB(255, 185, 176, 103)
          : loggedOut
          ? Colors.grey.shade600
          : buttonTheme.idleColor!,
      image: connected ? Assets.images.connectNorouz : Assets.images.disconnectNorouz,
      newButtonColor: connected ? buttonTheme.connectedColor! : buttonTheme.idleColor!,
      animated: connected || busy,
      useImage: today.day >= 19 && today.day <= 23 && today.month == 3,
      secureLabel: secureLabel,
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.buttonColor,
    required this.image,
    required this.useImage,
    required this.newButtonColor,
    required this.animated,
    required this.secureLabel,
  });

  final VoidCallback? onTap;
  final bool enabled;
  final String label;
  final Color buttonColor;
  final AssetGenImage image;
  final bool useImage;
  final String secureLabel;

  final Color newButtonColor;

  final bool animated;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // CircleDesignWidget(newButtonColor: newButtonColor, onTap: onTap, animated: animated),
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 16, color: buttonColor.withValues(alpha: .5))],
            ),
            width: 148,
            height: 148,
            child: Material(
              key: const ValueKey("home_connection_button"),
              shape: const CircleBorder(),
              color: Colors.white,
              child: InkWell(
                focusColor: Colors.grey,
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: useImage ? image.image() : Image.asset('assets/logo.png'),
                ),
              ),
            ).animate(target: enabled ? 0 : 1).blurXY(end: 1),
          ).animate(target: enabled ? 0 : 1).scaleXY(end: .88, curve: Curves.easeIn),
        ),
        const Gap(16),
        ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText(label, style: Theme.of(context).textTheme.titleMedium),
              if (secureLabel.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // const Gap(8),
                    Icon(FontAwesomeIcons.shieldHalved, size: 16, color: Theme.of(context).colorScheme.secondary),
                    const Gap(4),
                    Text(
                      secureLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.secondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
