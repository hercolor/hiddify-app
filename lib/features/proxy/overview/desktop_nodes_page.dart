import 'dart:async';

import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/dev_mode/dev_mode_providers.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';

import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final desktopNodeSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class _TopRoundIcon extends StatelessWidget {
  const _TopRoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
      ),
    );
  }
}

class _TestSpeedButton extends ConsumerWidget {
  const _TestSpeedButton({required this.groupTag});

  final String? groupTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTest = groupTag != null && groupTag!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTest
            ? () async {
                try {
                  await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(groupTag!);
                } catch (e) {
                  if (context.mounted) {
                    ref.read(inAppNotificationControllerProvider).showErrorToast('测速失败');
                  }
                }
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: canTest ? BrandDesktopColors.accent : BrandDesktopColors.cardElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: canTest
                ? [
                    BoxShadow(
                      color: BrandDesktopColors.accent.withOpacity(.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(Icons.speed_rounded, color: canTest ? Colors.white : BrandDesktopColors.textMuted, size: 20),
        ),
      ),
    );
  }
}

class DesktopNodesPage extends HookConsumerWidget {
  const DesktopNodesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(desktopNodeSearchProvider).trim().toLowerCase();
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    _useAutoLatencyRefresh(ref, proxies.valueOrNull?.tag);
    return DesktopTheme(
      child: DesktopBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: Column(
              children: [
                const Gap(10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TopRoundIcon(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.goNamed('home')),
                    const Text('选择节点', style: BrandDesktopText.pageTitle),
                    const SizedBox(width: 38),
                  ],
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: DesktopCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        borderColor: const Color(0xFFE2E8F0),
                        child: TextField(
                          onChanged: (value) => ref.read(desktopNodeSearchProvider.notifier).state = value,
                          decoration: const InputDecoration(
                            hintText: '搜索国家或地区...',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const Gap(10),
                    _TestSpeedButton(groupTag: proxies.valueOrNull?.tag),
                  ],
                ),
                const Gap(16),
                Expanded(
                  child: proxies.when(
                    data: (_) => _CachedDesktopNodes(search: search),
                    error: (_, _) => _CachedDesktopNodes(search: search),
                    loading: () => const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        // Keep desktop node browsing responsive; manual operations still show their own errors.
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

class _CachedDesktopNodes extends ConsumerWidget {
  const _CachedDesktopNodes({required this.search});

  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDevMode = ref.watch(devModeProvider);

    if (isDevMode) {
      final mockSelection = ref.watch(mockClientNodeSelectionProvider);
      final nodes = mockSelection.nodes
          .where((node) {
            if (search.isEmpty) return true;
            return safeNodeDisplayName(node.name).toLowerCase().contains(search);
          })
          .toList(growable: false);
      if (nodes.isEmpty) return const _EmptyNodesPanel();
      return _NodesList(
        itemCount: nodes.length,
        itemBuilder: (context, index) {
          final node = nodes[index];
          return _DesktopNodeTile(
            name: safeNodeDisplayName(node.name),
            delay: node.delay,
            selected: mockSelection.effectiveSelectedNodeId == node.id,
            onTap: () => _selectMockNode(ref, node.id, mockSelection.effectiveSelectedNodeId == node.id),
          );
        },
      );
    }

    final selection = ref.watch(clientNodeSelectionProvider);
    return selection.when(
      data: (state) {
        final nodes = state.nodes
            .where((node) {
              if (search.isEmpty) return true;
              return safeNodeDisplayName(node.name).toLowerCase().contains(search);
            })
            .toList(growable: false);
        if (nodes.isEmpty) return const _EmptyNodesPanel();
        return _NodesList(
          itemCount: nodes.length,
          itemBuilder: (context, index) {
            final node = nodes[index];
            return _DesktopNodeTile(
              name: safeNodeDisplayName(node.name),
              delay: node.delay,
              selected: state.effectiveSelectedNodeId == node.id,
              onTap: () => _selectCachedNode(ref, node.id, state.effectiveSelectedNodeId == node.id),
            );
          },
        );
      },
      error: (_, _) => const _EmptyNodesPanel(),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

Future<void> _selectMockNode(WidgetRef ref, String nodeId, bool selected) async {
  if (selected) return;
  ref.read(mockClientNodeSelectionProvider.notifier).selectNode(nodeId);
}

class _NodesList extends StatelessWidget {
  const _NodesList({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Gap(12),
      itemBuilder: itemBuilder,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.0 : 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? BrandDesktopColors.accent.withOpacity(.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? BrandDesktopColors.accent.withOpacity(.30) : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? BrandDesktopColors.accent.withOpacity(.12)
                    : const Color(0xFF0F172A).withOpacity(.025),
                blurRadius: selected ? 16 : 10,
                offset: Offset(0, selected ? 5.0 : 3.0),
              ),
              if (selected)
                BoxShadow(
                  color: BrandDesktopColors.accent.withOpacity(.06),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            children: [
              _NodeFlag(name: name, selected: selected),
              const Gap(10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandDesktopText.bodyPrimary.copyWith(
                    color: selected ? BrandDesktopColors.accent : BrandDesktopColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: delayColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  delayText,
                  style: BrandDesktopText.caption.copyWith(color: delayColor, fontWeight: FontWeight.w700),
                ),
              ),
              const Gap(8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? BrandDesktopColors.accent : BrandDesktopColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeFlag extends StatelessWidget {
  const _NodeFlag({required this.name, required this.selected});

  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final countryCode = _extractCountryCode(name);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? BrandDesktopColors.accent.withOpacity(0.1) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? BrandDesktopColors.accent.withOpacity(0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: countryCode != null
            ? CircleFlag(countryCode, size: 22)
            : const Icon(Icons.public_rounded, color: BrandDesktopColors.textMuted, size: 16),
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

Future<void> _selectCachedNode(WidgetRef ref, String nodeId, bool selected) async {
  if (selected) return;
  final state = ref.read(clientConnectionStateProvider);
  final wasConnected = state.phase == ClientConnectionPhase.connected;

  if (wasConnected) {
    ref.read(inAppNotificationControllerProvider).showInfoToast('正在切换节点并重新连接');
  }
  try {
    await ref.read(connectionNotifierProvider.notifier).switchSelectedNode(nodeId);
  } catch (_) {
    ref.read(inAppNotificationControllerProvider).showErrorToast('切换节点失败，请稍后重试');
  }
}

Color _delayColor(int? delay) {
  if (delay == null || delay == 0) return BrandDesktopColors.textMuted;
  if (delay < 800) return BrandDesktopColors.success;
  if (delay < 1500) return BrandDesktopColors.warning;
  return BrandDesktopColors.error;
}

String? _extractCountryCode(String nodeName) {
  final name = nodeName.toLowerCase();
  const map = {
    'us': ['美国', 'usa', 'united states', 'us-'],
    'jp': ['日本', 'japan', 'jp-'],
    'cn': ['中国', 'china', 'cn-'],
    'hk': ['香港', 'hong kong', 'hk-'],
    'tw': ['台湾', 'taiwan', 'tw-'],
    'sg': ['新加坡', 'singapore', 'sg-'],
    'kr': ['韩国', 'korea', 'kr-'],
    'gb': ['英国', 'uk', 'united kingdom', 'gb-'],
    'de': ['德国', 'germany', 'de-'],
    'fr': ['法国', 'france', 'fr-'],
    'ru': ['俄罗斯', 'russia', 'ru-'],
    'au': ['澳大利亚', 'australia', 'au-'],
    'ca': ['加拿大', 'canada', 'ca-'],
    'nl': ['荷兰', 'netherlands', 'nl-'],
    'in': ['印度', 'india', 'in-'],
    'br': ['巴西', 'brazil', 'br-'],
    'it': ['意大利', 'italy', 'it-'],
    'es': ['西班牙', 'spain', 'es-'],
  };
  for (final entry in map.entries) {
    for (final keyword in entry.value) {
      if (name.contains(keyword)) return entry.key;
    }
  }
  return null;
}
