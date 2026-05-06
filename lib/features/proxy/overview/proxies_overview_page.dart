import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/overview/desktop_nodes_page.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/proxy_tile.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _nodeSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class ProxiesOverviewPage extends HookConsumerWidget {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isWindows) return const DesktopNodesPage();

    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final search = ref.watch(_nodeSearchProvider).trim().toLowerCase();

    return Scaffold(
      extendBody: true,
      appBar: AppBar(toolbarHeight: 72, title: const Text('选择节点')),
      body: BrandScaffoldBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextField(
                  onChanged: (value) => ref.read(_nodeSearchProvider.notifier).state = value,
                  decoration: const InputDecoration(hintText: '搜索节点', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              Expanded(
                child: proxies.when(
                  data: (group) {
                    final allItems = (group?.items ?? []).where(ClientNodeParser.isUserVisibleOutbound).toList();
                    final items = search.isEmpty
                        ? allItems
                        : allItems.where((item) => item.tagDisplay.toLowerCase().contains(search)).toList();
                    if (group == null || allItems.isEmpty) {
                      return _CachedNodesList(search: search);
                    }
                    if (items.isEmpty) {
                      return const _EmptyNodes();
                    }
                    return RefreshIndicator(
                      onRefresh: () => ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(group.tag),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 112),
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: _NodePageIntro());
                          }
                          final proxy = items[index - 1];
                          return ProxyTile(
                            proxy,
                            selected: group.selected == proxy.tag,
                            onTap: () =>
                                ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(group.tag, proxy.tag),
                          );
                        },
                      ),
                    );
                  },
                  error: (_, _) => _CachedNodesList(search: search),
                  loading: () => const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CachedNodesList extends ConsumerWidget {
  const _CachedNodesList({required this.search});

  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(clientNodeSelectionProvider);
    return selection.when(
      data: (state) {
        final items = search.isEmpty
            ? state.nodes
            : state.nodes.where((node) => node.name.toLowerCase().contains(search)).toList(growable: false);
        if (items.isEmpty) return const _EmptyNodes();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 112),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: _NodePageIntro());
            }
            final node = items[index - 1];
            return _CachedNodeTile(
              node: node,
              selected: state.effectiveSelectedNodeId == node.id,
              onTap: () => ref.read(clientNodeSelectionProvider.notifier).selectNode(node.id),
            );
          },
        );
      },
      error: (_, _) => const _EmptyNodes(),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _CachedNodeTile extends StatelessWidget {
  const _CachedNodeTile({required this.node, required this.selected, required this.onTap});

  final ClientNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delay = node.delay;
    final delayText = delay == null || delay == 0
        ? '待测速'
        : delay > 65000
        ? '超时'
        : '$delay ms';
    final delayColor = delay == null || delay == 0
        ? BrandColors.muted
        : delay < 800
        ? BrandColors.success
        : delay < 1500
        ? BrandColors.warning
        : BrandColors.error;
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
                const Gap(14),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const Gap(10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: delayColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    delayText,
                    style: theme.textTheme.labelMedium?.copyWith(color: delayColor, fontWeight: FontWeight.w800),
                  ),
                ),
                const Gap(10),
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

class _NodePageIntro extends StatelessWidget {
  const _NodePageIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BorderRadius.circular(BrandRadii.lg),
        border: Border.all(color: BrandColors.border),
        boxShadow: BrandShadows.card,
      ),
      child: Row(
        children: [
          const BrandIcon(selected: true),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('智能线路', style: theme.textTheme.titleMedium),
                const Gap(3),
                Text('只展示节点名称与延迟，点击即可切换', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNodes extends StatelessWidget {
  const _EmptyNodes();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandIcon(size: 64, icon: Icons.hub_rounded),
          const Gap(16),
          Text('暂无可用节点', style: Theme.of(context).textTheme.titleMedium),
          const Gap(6),
          Text('请稍后重试或联系客服', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
