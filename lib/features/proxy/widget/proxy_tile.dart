import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hiddify/gen/fonts.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxyTile extends HookConsumerWidget {
  const ProxyTile(this.proxy, {super.key, required this.selected, required this.onTap});

  final OutboundInfo proxy;
  final bool selected;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final delay = proxy.urlTestDelay;
    final displayName = safeNodeDisplayName(proxy.tagDisplay.isNotEmpty ? proxy.tagDisplay : proxy.tag);
    final delayText = delay == 0
        ? '测速中'
        : delay > 65000
        ? '超时'
        : '$delay ms';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(BrandRadii.lg),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? BrandColors.mistBlue : BrandColors.card,
              borderRadius: BorderRadius.circular(BrandRadii.lg),
              border: Border.all(color: selected ? BrandColors.signalBlue.withValues(alpha: .35) : BrandColors.border),
              boxShadow: selected ? BrandShadows.glow(BrandColors.signalBlue, alpha: .10) : BrandShadows.card,
            ),
            child: Row(
              children: [
                BrandIcon(selected: selected, icon: Icons.hub_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
                      fontFamily: PlatformUtils.isWindows ? FontFamily.emoji : null,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.slate,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _DelayPill(delay: delay, label: delayText),
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? BrandColors.signalBlue : BrandColors.subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DelayPill extends StatelessWidget {
  const _DelayPill({required this.delay, required this.label});

  final int delay;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = delay == 0
        ? BrandColors.muted
        : delay < 800
        ? BrandColors.success
        : delay < 1500
        ? BrandColors.warning
        : BrandColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
