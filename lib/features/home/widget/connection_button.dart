import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(clientConnectionStateProvider);
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
            context.goNamed('membership');
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

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedScale(
        scale: animated ? 1.04 : 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? BrandColors.signalBlue : BrandColors.card,
            boxShadow: [
              BoxShadow(
                color: connected ? BrandColors.signalBlue.withOpacity(.30) : Colors.black.withOpacity(.05),
                blurRadius: connected ? 40 : 20,
                spreadRadius: connected ? 10 : 5,
                offset: const Offset(0, 10),
              ),
              if (busy) BoxShadow(color: accentColor.withOpacity(.18), blurRadius: 44, spreadRadius: 10),
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
                        dimension: 38,
                        child: CircularProgressIndicator(color: accentColor, strokeWidth: 3),
                      )
                    : Icon(
                        connected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                        size: 80,
                        color: connected ? Colors.white : BrandColors.subtle,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
