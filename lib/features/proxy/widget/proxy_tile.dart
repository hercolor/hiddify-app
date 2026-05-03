import 'package:flutter/material.dart';
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

    return ListTile(
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        proxy.tagDisplay,
        overflow: TextOverflow.ellipsis,
        style: PlatformUtils.isWindows ? const TextStyle(fontFamily: FontFamily.emoji) : null,
      ),
      leading: IPCountryFlag(selected: selected),
      trailing: Column(
        children: [
          if (proxy.urlTestDelay != 0)
            Text(
              proxy.urlTestDelay > 65000 ? "×" : proxy.urlTestDelay.toString(),
              style: TextStyle(color: delayColor(context, proxy.urlTestDelay)),
            ),

          if (proxy.download > 0) Text("⬩", style: Theme.of(context).textTheme.bodySmall),
        ],
      ),

      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      onTap: onTap,
      horizontalTitleGap: 4,
    );
  }

  Color delayColor(BuildContext context, int delay) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return switch (delay) {
        < 800 => Colors.lightGreen,
        < 1500 => Colors.orange,
        _ => Colors.redAccent,
      };
    }
    return switch (delay) {
      < 800 => Colors.green,
      < 1500 => Colors.deepOrangeAccent,
      _ => Colors.red,
    };
  }
}

class IPCountryFlag extends StatelessWidget {
  const IPCountryFlag({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.bolt_rounded,
        color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
