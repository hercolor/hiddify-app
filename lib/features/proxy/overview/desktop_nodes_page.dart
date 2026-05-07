import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final desktopNodeSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class DesktopNodesPage extends HookConsumerWidget {
  const DesktopNodesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(desktopNodeSearchProvider).trim().toLowerCase();
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    return DesktopPageScaffold(
      title: '选择节点',
      child: Column(
        children: [
          TextField(
            onChanged: (value) => ref.read(desktopNodeSearchProvider.notifier).state = value,
            decoration: const InputDecoration(hintText: '搜索节点', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const Gap(14),
          Expanded(
            child: proxies.when(
              data: (group) =>
                  group == null ? _CachedDesktopNodes(search: search) : _LiveDesktopNodes(group: group, search: search),
              error: (_, _) => _CachedDesktopNodes(search: search),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDesktopNodes extends ConsumerWidget {
  const _LiveDesktopNodes({required this.group, required this.search});

  final OutboundGroup group;
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = group.items
        .where(ClientNodeParser.isUserVisibleOutbound)
        .where((item) {
          if (search.isEmpty) return true;
          return _safeNodeName(item.tagDisplay.isNotEmpty ? item.tagDisplay : item.tag).toLowerCase().contains(search);
        })
        .toList(growable: false);

    if (items.isEmpty) return const _EmptyNodesPanel();
    return _NodesList(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final name = _safeNodeName(item.tagDisplay.isNotEmpty ? item.tagDisplay : item.tag);
        return _DesktopNodeTile(
          name: name,
          delay: item.urlTestDelay == 0 ? null : item.urlTestDelay,
          selected: group.selected == item.tag,
          onTap: () => _selectLiveNode(context, ref, group.tag, item.tag, group.selected == item.tag),
        );
      },
    );
  }
}

class _CachedDesktopNodes extends ConsumerWidget {
  const _CachedDesktopNodes({required this.search});

  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(clientNodeSelectionProvider);
    return selection.when(
      data: (state) {
        final nodes = state.nodes
            .where((node) {
              if (search.isEmpty) return true;
              return _safeNodeName(node.name).toLowerCase().contains(search);
            })
            .toList(growable: false);
        if (nodes.isEmpty) return const _EmptyNodesPanel();
        return _NodesList(
          itemCount: nodes.length,
          itemBuilder: (context, index) {
            final node = nodes[index];
            return _DesktopNodeTile(
              name: _safeNodeName(node.name),
              delay: node.delay,
              selected: state.effectiveSelectedNodeId == node.id,
              onTap: () => ref.read(clientNodeSelectionProvider.notifier).selectNode(node.id),
            );
          },
        );
      },
      error: (_, _) => const _EmptyNodesPanel(),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _NodesList extends StatelessWidget {
  const _NodesList({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const Gap(10),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

class _DesktopNodeTile extends StatelessWidget {
  const _DesktopNodeTile({required this.name, required this.delay, required this.selected, required this.onTap});

  final String name;
  final int? delay;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delayText = delay == null || delay == 0
        ? '待测速'
        : delay! > 65000
        ? '超时'
        : '$delay ms';
    final delayColor = _delayColor(delay);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? BrandDesktopColors.accent.withValues(alpha: .13)
                : BrandDesktopColors.cardElevated.withValues(alpha: .54),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? BrandDesktopColors.accent.withValues(alpha: .38) : BrandDesktopColors.border,
            ),
          ),
          child: Row(
            children: [
              DesktopIconBox(icon: Icons.route_rounded, selected: selected, size: 40),
              const Gap(14),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w800),
                ),
              ),
              const Gap(12),
              DesktopStatusPill(label: delayText, color: delayColor, icon: Icons.speed_rounded),
              const Gap(12),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? BrandDesktopColors.accent : BrandDesktopColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNodesPanel extends StatelessWidget {
  const _EmptyNodesPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DesktopCard(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DesktopIconBox(icon: Icons.hub_rounded, selected: true, size: 64),
            const Gap(18),
            Text(
              '暂无可用节点',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: BrandDesktopColors.textPrimary),
            ),
            const Gap(8),
            Text('请稍后重试或联系客服', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

Future<void> _selectLiveNode(
  BuildContext context,
  WidgetRef ref,
  String groupTag,
  String outboundTag,
  bool selected,
) async {
  if (selected) return;
  final state = ref.read(clientConnectionStateProvider);
  final wasConnected = state.phase == ClientConnectionPhase.connected;
  if (wasConnected) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('切换节点'),
        content: const Text('是否切换节点并重新连接？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('切换并重连')),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(groupTag, outboundTag);
  if (wasConnected) {
    final profile = await ref.read(activeProfileProvider.future);
    unawaited(ref.read(connectionNotifierProvider.notifier).reconnect(profile));
    ref.read(inAppNotificationControllerProvider).showInfoToast('正在切换节点并重新连接');
  }
}

Color _delayColor(int? delay) {
  if (delay == null || delay == 0) return BrandDesktopColors.textMuted;
  if (delay < 800) return BrandDesktopColors.success;
  if (delay < 1500) return BrandDesktopColors.warning;
  return BrandDesktopColors.error;
}

String _safeNodeName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'https?://[^\s]+'), '***')
      .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '***')
      .replaceAll(RegExp(r'\b[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:\d+)?\b'), '***');
  return sanitized.trim().isEmpty ? '未命名节点' : sanitized;
}
