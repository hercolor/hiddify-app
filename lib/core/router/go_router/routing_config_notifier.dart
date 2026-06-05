import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/router/adaptive_layout/my_adaptive_layout.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/custom_transition.dart';
import 'package:hiddify/core/router/go_router/refresh_listenable.dart';
import 'package:hiddify/features/auth/widget/auth_account_pages.dart';
import 'package:hiddify/features/diagnostics/diagnostics_page.dart';
import 'package:hiddify/features/home/widget/home_page.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:hiddify/features/legal/privacy_policy_page.dart';
import 'package:hiddify/features/legal/terms_of_service_page.dart';
import 'package:hiddify/features/premium/premium_screens.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_page.dart';
import 'package:hiddify/features/settings/overview/settings_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'routing_config_notifier.g.dart';

// each branch in go router has its own focus scope
final branchesScope = <String, FocusScopeNode>{
  'home': FocusScopeNode(),
  'profiles': FocusScopeNode(),
  'proxies': FocusScopeNode(),
  'settings': FocusScopeNode(),
};

// when the routing config is not yet initialized, this config is used
final loadingConfig = RoutingConfig(
  routes: <RouteBase>[GoRoute(path: '/home', builder: (context, state) => const Material())],
);

String getNameOfBranch(bool isMobileBreakpoint, bool showProfilesAction, int index) => isMobileBreakpoint
    ? ['home', 'proxies', 'settings'][index]
    : ['home', if (showProfilesAction) 'profiles', 'proxies', 'settings'][index];

int getIndexOfBranch(bool isMobileBreakpoint, bool showProfilesAction, String name) => isMobileBreakpoint
    ? ['home', 'proxies', 'settings'].indexOf(name)
    : ['home', if (showProfilesAction) 'profiles', 'proxies', 'settings'].indexOf(name);

@Riverpod(keepAlive: true)
class RoutingConfigNotifier extends _$RoutingConfigNotifier {
  @override
  RoutingConfig build() {
    final isMobileBreakpoint = ref.watch(isMobileBreakpointProvider);
    const showProfilesAction = false;
    if (isMobileBreakpoint == null) return loadingConfig;
    return RoutingConfig(
      redirect: (context, state) {
        final isIntro = state.matchedLocation == '/intro';
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
          builder: (_, _, navigationShell) => MyAdaptiveLayout(
            navigationShell: navigationShell,
            isMobileBreakpoint: isMobileBreakpoint,
            showProfilesAction: showProfilesAction,
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'home',
                  path: '/home',
                  builder: (_, _) => FocusScope(node: branchesScope['home'], child: const HomePage()),
                  routes: <GoRoute>[
                    if (isMobileBreakpoint)
                      GoRoute(name: 'profileDetails', path: '/profile-details/:id', redirect: (_, _) => '/settings'),
                  ],
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
                  name: 'settings',
                  path: '/settings',
                  pageBuilder: (_, state) => customTransition(
                    TransitionType.slide,
                    state.pageKey,
                    FocusScope(node: branchesScope['settings'], child: const SettingsPage()),
                  ),
                  routes: <GoRoute>[
                    GoRoute(name: 'general', path: '/general', redirect: (_, _) => '/settings'),
                    GoRoute(name: 'userProfile', path: '/user-profile', redirect: (_, _) => '/settings'),
                    GoRoute(
                      name: 'routeOptions',
                      path: '/route-options',
                      redirect: (_, _) => '/settings',
                      routes: <GoRoute>[
                        GoRoute(name: 'perAppProxy', path: '/per-app-proxy', redirect: (_, _) => '/settings'),
                      ],
                    ),
                    GoRoute(name: 'dnsOptions', path: '/dns-options', redirect: (_, _) => '/settings'),
                    GoRoute(name: 'inboundOptions', path: '/inbound-options', redirect: (_, _) => '/settings'),
                    GoRoute(name: 'tlsTricks', path: '/tls-tricks', redirect: (_, _) => '/settings'),
                    GoRoute(name: 'warpOptions', path: '/warp-options', redirect: (_, _) => '/settings'),
                  ],
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
