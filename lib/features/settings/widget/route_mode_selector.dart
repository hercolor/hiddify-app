import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 代理模式选择器。
///
/// 设计系统 v1 §5.3：这是「我的 › 高级」下的控件，**不放在连接页**——
/// 连接页只允许有一个主决策（连不连），分流是第二决策。
class RouteModeSelector extends ConsumerWidget {
  const RouteModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobalMode = ref.watch(ConfigOptions.globalRouteMode);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandPalette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RouteModeChoice(
              selected: !isGlobalMode,
              icon: Icons.alt_route_rounded,
              title: '智能分流',
              onTap: () => ref.read(ConfigOptions.globalRouteMode.notifier).update(false),
            ),
          ),
          Expanded(
            child: _RouteModeChoice(
              selected: isGlobalMode,
              icon: Icons.public_rounded,
              title: '全局代理',
              onTap: () => ref.read(ConfigOptions.globalRouteMode.notifier).update(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteModeChoice extends StatelessWidget {
  const _RouteModeChoice({required this.selected, required this.icon, required this.title, required this.onTap});

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [BrandPalette.brand, BrandPalette.brandDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [BoxShadow(color: BrandPalette.brand.withOpacity(.25), blurRadius: 8, offset: const Offset(0, 2))]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? BrandPalette.surface : BrandPalette.inkFaint, size: 18),
            const Gap(6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? BrandPalette.surface : BrandPalette.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
