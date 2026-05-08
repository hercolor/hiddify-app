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


## Blocking Audit Helper Contract
- [x] `scripts/verify_forbidden_audit_classified.py` exists and supports `--self-test`.
- [x] Phase completion must run raw `rg` collection into `.omx/logs/phase-N-*-audit.txt`, then run the helper as the blocking gate.
- [x] Required tests and helper self-test must not use fallback `|| true`; only raw exploratory collection may use `|| true` before the blocking classifier.
- [x] Forbidden regex includes: `全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护|4376 VPN`.

## Required Safety Tasks
- [x] Add/reuse one centralized UI-only `safeNodeDisplayName` helper at `lib/features/proxy/widget/safe_node_display_name.dart`.
- [x] Add/run `test/features/proxy/widget/safe_node_display_name_test.dart` for URL, IPv4, IPv6, domain/domain:port, protocol-like prefix, raw fragment, blank/overlong, and normal names.
- [x] Confirm `safeNodeDisplayName` is not used in node IDs, selection storage, outbound tags, core config, or subscription parsing.
- [x] Apply helper to Android Home current node.
- [x] Apply helper to Windows Home current node.
- [x] Apply helper to Android Nodes live/cached list labels.
- [x] Apply helper to Windows Nodes live/cached list labels.
- [x] Apply helper to Nodes search matching.
- [x] Apply helper to Windows tray current node.
- [x] Remove/hide all no-op logged-out `忘记密码` buttons unless real reset URL/config already exists; no hardcoded reset/support URL.
- [x] Confirm legacy `/settings` route is not visible as normal Settings UI.
- [x] Audit user-visible normal UI/tray/navigation/resources for forbidden technical/subscription strings, including standalone `Settings` and bounded `IP/IPv4/IPv6` and classify every hit as forbidden/internal/diagnostics/legal/generated/icon.

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
| Phase 1 | task-owned diff | allowed-test-doc-only | Phase 1 task-owned files did not include core/API/native/connection state-machine paths; full diff guard still reports pre-existing dirty tree from Phase 0. | Commit only Phase 1 UI/helper/test files. |
| Phase 2 | task-owned diff | allowed-test-doc-only | Phase 2 only aligns logged-out Login/Membership helper text with demo/product copy and updates this checklist. | Commit only Phase 2 UI text and checklist files. |
| Phase 3 | task-owned diff | allowed-test-doc-only | Phase 3 centralizes customer-service URI parsing for Membership renewal/upgrade/support actions and adds unit coverage. | Commit only helper, Membership imports, helper test, and checklist. |
| Phase 4 | existing dirty tree | blocker-needs-separate-approval | Final diff guard still reports the same broad pre-existing dirty tree under native/core/profile/connection/windows-runner paths, plus unrelated normal-UI files from earlier work. | Do not stage unrelated dirty files; final phase commits checklist evidence only. |

## Phase Commit Evidence

| Phase | Commit hash | Scope | Lore trailers summary | Commands run | Pass/Fail | Blocker/Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 0 | 5ef93668 | Baseline checklist/audit intake | Constraint/Directive/Tested/Not-tested recorded | `git status --short --ignore-submodules=all`; forbidden baseline audit; hardcoded URL baseline; `git diff --name-only --ignore-submodules=all` guard | pass-with-existing-dirty-tree-noted | Existing working tree has many pre-existing dirty files; Phase 0 committed only checklist evidence. |
| Phase 1 | 2f66e2b6 (+ checklist evidence commit) | Node label safety + route guard | Constraint/Rejected/Directive/Tested/Not-tested recorded | dart format; flutter test safe_node_display_name_test; dart analyze changed files; flutter pub get && flutter analyze; helper/raw-name/no-op/forbidden/URL/diff audits | pass-with-existing-dirty-tree-noted | Code commit 2f66e2b6. Existing unrelated diff-guard hits remain pre-existing and were not staged. |
| Phase 2 | ff9f0f1e | UI parity pages | Constraint/Rejected/Directive/Tested/Not-tested recorded | dart format; dart analyze changed files; flutter pub get && flutter analyze; flutter build apk --debug -t lib/main.dart; flutter build windows --release -t lib/main.dart | pass-with-android-env-blocker | Login helper copy now matches demo/product wording. Android debug build blocked by local Java 8 vs Gradle Java 11 requirement; Windows release build passed and produced `build\\windows\\x64\\runner\\Release\\4376.exe`. |
| Phase 3 | 30bf5059 | Safe business action mapping | Constraint/Rejected/Directive/Tested/Not-tested recorded | dart format; flutter test customer_service_uri_test; dart analyze changed files; flutter analyze | pass | Renewal/upgrade/support now reuse backend-provided `customer_service` only and allow only http/https/tg/mailto/plain email; no fake invite/feedback/website actions implemented. |
| Phase 4 | 7bbcd0d9 | Final audit/release sweep | Constraint/Rejected/Directive/Tested/Not-tested recorded | forbidden-string audit; hardcoded URL audit; diff guard; flutter pub get; flutter analyze; flutter build windows --release -t lib/main.dart; java -version; flutter build apk --debug -t lib/main.dart | pass-with-android-env-blocker | Windows release build passed: `build\\windows\\x64\\runner\\Release\\4376.exe`. Android debug build blocked by local Java 8 while Gradle requires Java 11. Existing dirty tree remains pre-existing and unstaged. |

## Forbidden-String Audit Classification

Every audit hit from the required `rg` command must be recorded here before a phase is complete. Category must be exactly one of: `normal-ui-blocker`, `internal`, `diagnostics`, `legal`, `generated`, `icon/constant` (legacy `forbidden`/`icon` rows are treated as blocking/constant by `scripts/verify_forbidden_audit_classified.py`). The blocking audit helper must fail on unclassified hits and on `normal-ui-blocker`/`forbidden` classifications.

| Phase | file:line | Matched string | Surface | Category | Rationale | Action/blocker |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 0 | lib/features/auth/widget/* | 用户协议 | Membership legal entry | legal | Required local terms entry, allowed. | none |
| Phase 0 | lib/core/router/go_router/routing_config_notifier.dart | settings | Internal route wrapper | internal | Legacy route renders Membership/UserProfile, not visible Settings page. | none |
| Phase 0 | lib/features/home/widget/connection_button.dart / desktop_home_page.dart | goNamed('settings') | Internal redirect | internal | Logged-out connect redirects to membership/login wrapper; no visible Settings label. | none |
| Phase 0 | lib/core/router/deep_linking/* | protocol | Internal URL protocol code | internal | Not normal Home/Nodes/Membership UI. | none |
| Phase 0 | lib/core/router/dialog/widgets/proxy_info_dialog.dart | port/host/IP | Legacy technical dialog | diagnostics | Existing technical dialog hit; not introduced by rollout and outside normal pages. | Do not expand exposure; future separate cleanup if reachable. |
| Phase 0 | android/app/src/main/res/xml/network_security_config.xml | domain | Android network resource | internal | Not user-visible UI. | none |
| Phase 0 | android/app/src/main/res/xml/shortcuts.xml | hiddify package path | generated/internal | Package/native path, not user-visible label. | none |
| Phase 1 | lib/features/proxy/widget/safe_node_display_name.dart | server/address/domain/port/cipher/password/http/tg/mailto | UI sanitizer implementation | internal | Regex literals are masking rules, not rendered user text or fallback service URLs. | none |
| Phase 1 | lib/features/system_tray/notifier/system_tray_notifier.dart | current node sanitized | Tray current-node surface | internal | Tray now uses `safeNodeDisplayName(..., fallback: 暂无可用节点)`. | none |
| Phase 3 | lib/features/auth/widget/customer_service_uri.dart | http/https/tg/mailto | Customer-service URI parser | internal | Allowed URI schemes for backend-provided `customer_service`; not hardcoded support destination. | none |
| Phase 3 | test/features/auth/widget/customer_service_uri_test.dart | example.com/t.me/mailto | Unit test fixtures | internal | Test-only configured-link fixtures; not normal UI or production default URLs. | none |
| Phase 4 | lib/features/auth/widget/* | 登录后将自动同步节点 | Login helper copy | internal | Informational product copy required by demo/product login UX; it is not an import/copy/refresh/sync button or subscription URL entry. | none |
| Phase 4 | lib/core/router/go_router/routing_config_notifier.dart / connection_button.dart / desktop_home_page.dart | settings | Internal route compatibility | internal | Legacy route name/path still renders Membership/Login wrapper; no visible Settings tab/page. | none |
| Phase 4 | lib/core/router/dialog/widgets/proxy_info_dialog.dart | host/port/IP | Existing technical dialog | diagnostics | Pre-existing diagnostics/technical dialog; not introduced by this rollout and not part of normal Home/Nodes/Membership pages. | none |
| Phase 4 | lib/features/proxy/widget/safe_node_display_name.dart | server/address/domain/port/cipher/http/tg/mailto | Sanitizer implementation | internal | Regex literals and masking rules only; not rendered as normal UI content. | none |
| Phase 4 | android/app/src/main/res/xml/network_security_config.xml / shortcuts.xml | domain/hiddify package path | Android resource | internal | Network resource/package target class, not normal UI label. | none |

## Verification Log
- [x] `dart format --page-width 120 <changed files>`
- [x] `dart analyze <changed files>`
- [x] `flutter pub get && flutter analyze`
- [ ] `flutter build apk --debug -t lib/main.dart` (blocked in this environment: Java 8 runtime, Gradle dependency requires Java 11)
- [x] Windows-capable runner: `flutter build windows --release -t lib/main.dart`
- [x] Forbidden-string audit with allowlist classification.
- [ ] Manual smoke: Android Login/Home/Nodes/Membership.
- [ ] Manual smoke: Windows Login/Home/Nodes/Membership/tray.
- [x] Diff audit: no server/XBoard API/node backend/core protocol/connection state-machine changes unless separately requested.
- [x] Customer-service source audit: Membership/Login/Home/Nodes/tray contain no hardcoded service URLs; only sanitizer regex literals contain URL patterns.
- [x] Customer-service URI unit test: backend-provided http/https/tg/mailto/plain email accepted; blank/unsupported schemes rejected.
