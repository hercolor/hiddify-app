import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/dev_mode/dev_mode_providers.dart';
import 'package:hiddify/features/home/widget/shared_home_widgets.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MobileHomePage extends HookConsumerWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const config = HomeConfig.desktop;
    final isDevMode = ref.watch(devModeProvider);
    final state = isDevMode
        ? ref.watch(mockClientConnectionStateProvider)
        : ref.watch(clientConnectionStateProvider);

    late final String nodeName;
    late final ClientNode? selectedNode;
    late final List<ClientNode> nodes;

    if (isDevMode) {
      final mockSelection = ref.watch(mockClientNodeSelectionProvider);
      selectedNode = mockSelection.selectedNode;
      nodes = mockSelection.nodes;
      nodeName = safeNodeDisplayName(
        selectedNode?.name ?? (nodes.isNotEmpty ? nodes.first.name : null),
        fallback: '暂无可用节点',
      );
    } else {
      final nodeSelection = ref.watch(clientNodeSelectionProvider);
      nodeName = nodeSelection.when(
        data: (sel) => safeNodeDisplayName(
          sel.selectedNode?.name ?? (sel.nodes.isNotEmpty ? sel.nodes.first.name : null),
          fallback: '暂无可用节点',
        ),
        error: (_, _) => '暂无可用节点',
        loading: () => '读取线路中',
      );
      final selection = nodeSelection.valueOrNull;
      selectedNode = selection?.selectedNode;
      nodes = selection?.nodes ?? [];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2FA),
      body: Stack(
        children: [
          // Decorative background orbs
          Positioned(
            top: 80,
            right: -40,
            child: _BackgroundOrb(
              width: 140,
              height: 140,
              color: const Color(0xFF6366F1),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: _BackgroundOrb(
              width: 160,
              height: 160,
              color: const Color(0xFF06B6D4),
              opacity: 0.08,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(config.bodyPadding, 12, config.bodyPadding, 0),
                  child: SharedHomeHeader(config: config),
                ),
                const Spacer(flex: 2),
                // Connection hero with gradient card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: config.bodyPadding),
                  child: SharedConnectionHero(
                    config: config,
                    state: state,
                    isDevMode: isDevMode,
                  ),
                ),
                const Spacer(flex: 3),
                // Node card with flag
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: config.bodyPadding),
                  child: SharedNodeCard(
                    config: config,
                    nodeName: nodeName,
                    isDevMode: isDevMode,
                  ),
                ),
                const Spacer(flex: 1),
                // Route toggle
                Padding(
                  padding: EdgeInsets.fromLTRB(config.bodyPadding, 0, config.bodyPadding, 12),
                  child: const SharedRouteToggle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double opacity;

  const _BackgroundOrb({
    required this.width,
    required this.height,
    required this.color,
    this.opacity = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.33),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
