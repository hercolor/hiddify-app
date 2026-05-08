# 4376 Flutter UI Demo Rollout Checklist

Source demo: `docs/flutter_ui_demo.dart`

## Classification

| Demo item | Status | Production mapping | Notes |
| --- | --- | --- | --- |
| LoginScreen | Implement now | Membership logged-out state | Preserve real auth, validation, auto node sync. |
| MainScreen bottom nav | Implement now | Home / Nodes / Membership shell | No visible Settings tab. |
| HomeTab | Implement now | Real connection state and selected node | No fake `VpnState` or fake timer. |
| NodesTab | Implement now | Live/cache node lists | Use sanitized node display names only. |
| ProfileTab | Implement now | Membership page | Real plan/expiry/traffic/devices/support/legal/logout. |
| RenewalScreen | Map to existing service | parsed `subscription.customerService` from backend `customer_service` only in this rollout | No fake plans/prices/payment. |
| InviteScreen | Proposal only | Requires backend invite/referral URL | No hardcoded invite link. |
| FeedbackScreen | Proposal only | Requires backend/email/customer-service destination | No local dead form. |
| WebsiteScreen | Proposal only | Requires trusted configured official URL | No hardcoded `4376.net`. |
| SettingsScreen | Forbidden in normal UI | None | No advanced settings/Kill Switch/DNS/fake-ip/IPv6/route/protocol controls. |

## Required Safety Tasks
- [ ] Add/reuse one centralized UI-only `safeNodeDisplayName` helper at `lib/features/proxy/widget/safe_node_display_name.dart`.
- [ ] Add/run `test/features/proxy/widget/safe_node_display_name_test.dart` for URL, IPv4, IPv6, domain/domain:port, protocol-like prefix, raw fragment, blank/overlong, and normal names.
- [ ] Confirm `safeNodeDisplayName` is not used in node IDs, selection storage, outbound tags, core config, or subscription parsing.
- [ ] Apply helper to Android Home current node.
- [ ] Apply helper to Windows Home current node.
- [ ] Apply helper to Android Nodes live/cached list labels.
- [ ] Apply helper to Windows Nodes live/cached list labels.
- [ ] Apply helper to Nodes search matching.
- [ ] Apply helper to Windows tray current node.
- [ ] Remove/hide all no-op logged-out `忘记密码` buttons unless real reset URL/config already exists; no hardcoded reset/support URL.
- [ ] Confirm legacy `/settings` route is not visible as normal Settings UI.
- [ ] Audit user-visible normal UI/tray/navigation/resources for forbidden technical/subscription strings, including standalone `Settings` and bounded `IP/IPv4/IPv6` and classify every hit as forbidden/internal/diagnostics/legal/generated/icon.

## Deferred Proposals Requiring Real Source
- Renewal/order URL API or app config field.
- Invite/referral URL API and terms.
- Feedback destination API/email/customer-service channel.
- Official website URL config.
- Password reset URL or support flow.

## Path-Level Diff Guard

Record any hit from the required `git diff --name-only` guard. Category must be `allowed-test-doc-only` or `blocker-needs-separate-approval`.

| Phase | Path | Category | Rationale | Action/blocker |
| --- | --- | --- | --- | --- |
| Phase 0 | existing dirty tree | blocker-needs-separate-approval | Baseline diff guard reports many pre-existing changes under Android native, hiddifycore, singbox, profile data, connection data, windows runner. | Do not stage or modify in UI rollout; later phase commits must include only task-owned files. |

## Phase Commit Evidence

| Phase | Commit hash | Scope | Lore trailers summary | Commands run | Pass/Fail | Blocker/Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 0 | pending | Baseline checklist/audit intake | Constraint/Directive/Tested trailers required | `git status --short --ignore-submodules=all`; forbidden baseline audit; hardcoded URL baseline; `git diff --name-only --ignore-submodules=all` guard | pass-with-existing-dirty-tree-noted | Existing working tree has many pre-existing dirty files; Phase 0 commits only this checklist update. |
| Phase 1 | pending | Node label safety + route guard | pending | pending | pending | Required before broader UI polish. |
| Phase 2 | pending | UI parity pages | pending | pending | pending | Android + Windows page checks. |
| Phase 3 | pending | Safe business action mapping | pending | pending | pending | No fake URLs/no dead buttons. |
| Phase 4 | pending | Final audit/release sweep | pending | pending | pending | Builds + forbidden-string classification. |

## Forbidden-String Audit Classification

Every audit hit from the required `rg` command must be recorded here before a phase is complete. Category must be exactly one of: `forbidden`, `internal`, `diagnostics`, `legal`, `generated`, `icon`.

| Phase | file:line | Matched string | Surface | Category | Rationale | Action/blocker |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 0 | lib/features/auth/widget/* | 用户协议 | Membership legal entry | legal | Required local terms entry, allowed. | none |
| Phase 0 | lib/core/router/go_router/routing_config_notifier.dart | settings | Internal route wrapper | internal | Legacy route renders Membership/UserProfile, not visible Settings page. | none |
| Phase 0 | lib/features/home/widget/connection_button.dart / desktop_home_page.dart | goNamed('settings') | Internal redirect | internal | Logged-out connect redirects to membership/login wrapper; no visible Settings label. | none |
| Phase 0 | lib/core/router/deep_linking/* | protocol | Internal URL protocol code | internal | Not normal Home/Nodes/Membership UI. | none |
| Phase 0 | lib/core/router/dialog/widgets/proxy_info_dialog.dart | port/host/IP | Legacy technical dialog | diagnostics | Existing technical dialog hit; not introduced by rollout and outside normal pages. | Do not expand exposure; future separate cleanup if reachable. |
| Phase 0 | android/app/src/main/res/xml/network_security_config.xml | domain | Android network resource | internal | Not user-visible UI. | none |
| Phase 0 | android/app/src/main/res/xml/shortcuts.xml | hiddify package path | generated/internal | Package/native path, not user-visible label. | none |

## Verification Log
- [ ] `dart format --page-width 120 <changed files>`
- [ ] `dart analyze <changed files>`
- [ ] `flutter pub get && flutter analyze`
- [ ] `flutter build apk --debug -t lib/main.dart`
- [ ] Windows-capable runner: `flutter build windows --release -t lib/main.dart`
- [ ] Forbidden-string audit with allowlist classification.
- [ ] Manual smoke: Android Login/Home/Nodes/Membership.
- [ ] Manual smoke: Windows Login/Home/Nodes/Membership/tray.
- [ ] Diff audit: no server/XBoard API/node backend/core protocol/connection state-machine changes unless separately requested.
- [ ] Customer-service source audit: Membership/Login/Home/Nodes/tray contain no hardcoded `http://`, `https://`, `tg://`, `mailto:`, `4376.net`, or default support URL; UI only consumes `subscription.customerService`.
