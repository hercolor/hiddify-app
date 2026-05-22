import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class EmptyProfilesHomeBody extends HookConsumerWidget {
  const EmptyProfilesHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 48),
          const Gap(16),
          const Text('请先登录会员账号'),
          const Gap(8),
          Text('登录后会自动完成线路准备', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// class EmptyActiveProfileHomeBody extends HookConsumerWidget {
//   const EmptyActiveProfileHomeBody({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
// //     return SliverFillRemaining(
//       hasScrollBody: false,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(t.home.noActiveProfileMsg),
//           const Gap(16),
//           OutlinedButton(
//             onPressed: () => const ProfilesOverviewRoute().push(context),
//             child: Text(t.profile.overviewPageTitle),
//           ),
//         ],
//       ),
//     );
//   }
// }
