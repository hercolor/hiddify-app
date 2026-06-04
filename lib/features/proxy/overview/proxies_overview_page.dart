import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/overview/desktop_nodes_page.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
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
    _useAutoLatencyRefresh(ref, proxies.valueOrNull?.tag);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const _MobileBackButton(),
        toolbarHeight: 72,
        title: const Text('选择节点'),
        titleTextStyle: BrandText.pageTitle,
      ),
      body: BrandScaffoldBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextField(
                  onChanged: (value) => ref.read(_nodeSearchProvider.notifier).state = value,
                  decoration: const InputDecoration(hintText: '搜索国家或地区...', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              Expanded(
                child: proxies.when(
                  data: (group) => group == null
                      ? _CachedNodesList(search: search)
                      : RefreshIndicator(
                          onRefresh: () => ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(group.tag),
                          child: _CachedNodesList(search: search),
                        ),
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

class _MobileBackButton extends StatelessWidget {
  const _MobileBackButton();

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

void _useAutoLatencyRefresh(WidgetRef ref, String? groupTag) {
  useEffect(() {
    if (groupTag == null || groupTag.isEmpty) return null;

    var disposed = false;
    Future<void> refresh() async {
      if (disposed) return;
      try {
        await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(groupTag, withHaptic: false);
      } catch (_) {
        // Keep the node page responsive; manual pull-to-refresh still surfaces failures.
      }
    }

    unawaited(Future<void>.microtask(refresh));
    final timer = Timer.periodic(const Duration(seconds: 10), (_) => unawaited(refresh()));
    return () {
      disposed = true;
      timer.cancel();
    };
  }, [groupTag]);
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
            : state.nodes
                  .where((node) => safeNodeDisplayName(node.name).toLowerCase().contains(search))
                  .toList(growable: false);
        if (items.isEmpty) return const _EmptyNodes();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 112),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final node = items[index];
            return _CachedNodeTile(
              node: node,
              selected: state.effectiveSelectedNodeId == node.id,
              onTap: () => _selectCachedNode(context, ref, node.id, state.effectiveSelectedNodeId == node.id),
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
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? BrandColors.mistBlue : BrandColors.card,
              borderRadius: BorderRadius.circular(BrandRadii.lg),
              border: Border.all(color: selected ? BrandColors.signalBlue.withOpacity(.35) : BrandColors.border),
              boxShadow: selected ? BrandShadows.glow(BrandColors.signalBlue, alpha: .10) : BrandShadows.card,
            ),
            child: Row(
              children: [
                BrandIcon(selected: selected, icon: Icons.language_rounded),
                const Gap(14),
                Expanded(
                  child: Text(
                    safeNodeDisplayName(node.name),
                    overflow: TextOverflow.ellipsis,
                    style: BrandText.bodyPrimary,
                  ),
                ),
                const Gap(10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: delayColor.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    delayText,
                    style: BrandText.caption.copyWith(color: delayColor, fontWeight: FontWeight.w600),
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

Future<void> _selectCachedNode(BuildContext context, WidgetRef ref, String nodeId, bool selected) async {
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

  await ref.read(clientNodeSelectionProvider.notifier).selectNode(nodeId);
  if (wasConnected) {
    final profile = await ref.read(activeProfileProvider.future);
    unawaited(ref.read(connectionNotifierProvider.notifier).reconnect(profile));
    ref.read(inAppNotificationControllerProvider).showInfoToast('正在切换节点并重新连接');
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
