import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/router/adaptive_layout/my_adaptive_layout.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/custom_transition.dart';
import 'package:hiddify/core/router/go_router/refresh_listenable.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/auth/widget/auth_account_pages.dart';
import 'package:hiddify/features/auth/widget/user_profile_page.dart';
import 'package:hiddify/features/diagnostics/diagnostics_page.dart';
import 'package:hiddify/features/home/widget/home_page.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:hiddify/features/legal/privacy_policy_page.dart';
import 'package:hiddify/features/legal/terms_of_service_page.dart';
import 'package:hiddify/features/premium/premium_screens.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'routing_config_notifier.g.dart';

// each branch in go router has its own focus scope
final branchesScope = <String, FocusScopeNode>{
  'home': FocusScopeNode(),
  'proxies': FocusScopeNode(),
  'membership': FocusScopeNode(),
};

// when the routing config is not yet initialized, this config is used
final loadingConfig = RoutingConfig(
  routes: <RouteBase>[GoRoute(path: '/home', builder: (context, state) => const Material())],
);

String getNameOfBranch(bool isMobileBreakpoint, int index) => ['home', 'proxies', 'membership'][index];

int getIndexOfBranch(bool isMobileBreakpoint, String name) => ['home', 'proxies', 'membership'].indexOf(name);

@Riverpod(keepAlive: true)
class RoutingConfigNotifier extends _$RoutingConfigNotifier {
  @override
  RoutingConfig build() {
    final isMobileBreakpoint = ref.watch(isMobileBreakpointProvider);
    // watch auth so RoutingConfig rebuilds when login state changes
    ref.watch(authNotifierProvider);
    if (isMobileBreakpoint == null) return loadingConfig;
    return RoutingConfig(
      redirect: (context, state) {
        final isLoggedIn = ref.read(authNotifierProvider).valueOrNull?.isLoggedIn == true;
        final matched = state.matchedLocation;

        // 未登录时，/home 和 /proxies 重定向到 /membership，但注册/忘记密码页放行
        if (!isLoggedIn && matched != '/membership' && matched != '/auth/register' && matched != '/auth/forgot-password') {
          return '/membership';
        }

        final isIntro = matched == '/intro';
        // fix path-parameters for deep link
        String? url;
        if (LinkParser.protocols.contains(state.uri.scheme)) {
          url = state.uri.toString();
        } else if (PlatformUtils.isDesktop && newUrlFromAppLink.isNotEmpty) {
          url = newUrlFromAppLink;
          newUrlFromAppLink = '';
        } else if (state.uri.queryParameters['url'] != null) {
          url = state.uri.queryParameters['url'];
        }

        if (isIntro) {
          return '/home';
        } else if (url != null) {
          return '/home';
        }
        return null;
      },
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) =>
              MyAdaptiveLayout(navigationShell: navigationShell, isMobileBreakpoint: isMobileBreakpoint),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'home',
                  path: '/home',
                  builder: (_, _) => FocusScope(node: branchesScope['home'], child: const HomePage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'proxies',
                  path: '/proxies',
                  pageBuilder: (_, state) => customTransition(
                    TransitionType.slide,
                    state.pageKey,
                    FocusScope(node: branchesScope['proxies'], child: const ProxiesOverviewPage()),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'membership',
                  path: '/membership',
                  builder: (_, _) => FocusScope(node: branchesScope['membership'], child: const UserProfilePage()),
                ),
              ],
            ),
          ],
        ),

        GoRoute(
          name: 'authRegister',
          path: '/auth/register',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const AuthRegisterPage()),
        ),
        GoRoute(
          name: 'authForgotPassword',
          path: '/auth/forgot-password',
          pageBuilder: (_, state) =>
              customTransition(TransitionType.slide, state.pageKey, const AuthForgotPasswordPage()),
        ),
        GoRoute(
          name: 'securityCenter',
          path: '/auth/security-center',
          pageBuilder: (_, state) =>
              customTransition(TransitionType.slide, state.pageKey, const UserSecurityCenterPage()),
        ),
        GoRoute(
          name: 'premiumRenewal',
          path: '/premium/renewal',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PremiumRenewalPage()),
        ),
        GoRoute(
          name: 'premiumInvite',
          path: '/premium/invite',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PremiumInvitePage()),
        ),
        GoRoute(
          name: 'premiumFeedback',
          path: '/premium/feedback',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PremiumFeedbackPage()),
        ),
        GoRoute(
          name: 'premiumWebsite',
          path: '/premium/website',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PremiumWebsitePage()),
        ),
        GoRoute(
          name: 'premiumContact',
          path: '/premium/contact',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PremiumContactPage()),
        ),
        GoRoute(
          name: 'premiumAbout',
          path: '/premium/about',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PremiumAboutPage()),
        ),
        GoRoute(
          name: 'premiumPreferences',
          path: '/premium/preferences',
          pageBuilder: (_, state) =>
              customTransition(TransitionType.slide, state.pageKey, const PremiumPreferencesPage()),
        ),
        GoRoute(
          name: 'diagnostics',
          path: '/diagnostics',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const DiagnosticsPage()),
        ),
        GoRoute(
          name: 'privacyPolicy',
          path: '/privacy-policy',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const PrivacyPolicyPage()),
        ),
        GoRoute(
          name: 'termsOfService',
          path: '/terms-of-service',
          pageBuilder: (_, state) => customTransition(TransitionType.slide, state.pageKey, const TermsOfServicePage()),
        ),
        GoRoute(name: 'intro', path: '/intro', builder: (_, _) => const IntroPage()),
      ],
    );
  }
}
