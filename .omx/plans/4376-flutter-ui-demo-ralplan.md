# RALPLAN-DR: 4376 Flutter UI Demo Comprehensive Landing Plan

## Outcome
全面推进 `docs/flutter_ui_demo.dart` 的 UI 与功能落地，但以 4376 生产客户端规则为边界：demo 是视觉/交互目录，不是生产代码来源。Android 与 Windows 只在正常用户页面 Home / Nodes / Membership 内落地；所有业务动作必须接真实已有服务、后端配置或安全本地页面，不能复制 fake state、fake data、fake payment、fake settings。

## Evidence Baseline
- Demo reference: `docs/flutter_ui_demo.dart` includes `LoginScreen`, `MainScreen`, `HomeTab`, `NodesTab`, `ProfileTab`, plus demo-only `RenewalScreen`, `InviteScreen`, `FeedbackScreen`, `WebsiteScreen`, `SettingsScreen`.
- Demo contains fake/local behavior: local `VpnState`, hardcoded nodes, hardcoded member/expiry/plans/prices, hardcoded invite/website links, fake payment/feedback SnackBars, and Settings/Kill Switch/language/cache UI.
- Production already has real auth login and subscription/node sync in `lib/features/auth/notifier/auth_notifier.dart`; `XBoardLoginService` remains internal only.
- Production has real connection state and idempotent start/stop in `lib/features/connection/notifier/connection_notifier.dart`.
- Production has live/cached nodes in `lib/features/proxy/overview/*` and `lib/features/proxy/data/client_node_store.dart`.
- Production has membership/customer-service/legal/hidden diagnostics in `lib/features/auth/widget/user_profile_page.dart`, `lib/features/auth/widget/desktop_membership_page.dart`, diagnostics routes, and legal routes.
- Current visible navigation is Home / Nodes / Membership. A legacy internal route named `settings` currently renders `SettingsPage -> UserProfilePage`; it is a compatibility wrapper, not a normal Settings page.
- Recent commit `f8e45e07` improved core UI parity but did not intentionally add demo-only feature pages.

## RALPLAN-DR

### Principles
1. **Demo as visual/interaction catalog**: copy design intent, not demo-local fake state/data.
2. **Product safety overrides visual completeness**: normal UI remains Home / Nodes / Membership; no visible Settings or technical/core configuration.
3. **Real source for every function**: no hardcoded payment, invite, website, feedback, reset-password, node, subscription, or support endpoints.
4. **Preserve production contracts**: do not modify server, XBoard API, node backend, core protocol, auth sync, node import, connection state machine, or Windows network mode unless separately requested.
5. **Phase, verify, commit**: each completed modification phase runs formatting, analysis/build checks, visible-string audit, and git commit using Lore trailers.

### Decision Drivers
1. User wants demo UI and functionality comprehensively advanced, not only partial color/layout polish.
2. Several demo screens/functions are incompatible with 4376 product rules unless converted to existing real services/configuration.
3. Auth sync, selected node, one-click connect, Windows tray/network behavior, and secret-safety must not regress.

### Options

#### Option A — Literal demo clone
- Pros: fastest apparent demo parity.
- Cons: imports fake `VpnState`, fake nodes/plans/payment/invite/website/settings; violates normal UI and technical-exposure rules.
- Decision: **Rejected**.

#### Option B — Product-safe phased rollout
- Pros: advances UI/functionality comprehensively while using existing production services; minimizes regression risk; can be committed phase-by-phase.
- Cons: demo-only functions without real backend/config become proposals or customer-service fallbacks, so parity is not literal.
- Decision: **Chosen**.

#### Option C — UI-only polish
- Pros: safest technically.
- Cons: insufficient for “功能落地”.
- Decision: **Rejected as incomplete**.

#### Option D — Hidden demo routes
- Pros: preserves demo pages for internal preview.
- Cons: maintenance/fake-data risk and not normal UX; can still accidentally expose forbidden Settings/fake flows.
- Decision: **Rejected unless a separate internal-demo task is requested**.

## Demo Item Classification

### Implement Now
- UI parity for Login, Home, Nodes, Membership on Android and Windows.
- Windows fixed 390x910 shell consistency and bottom navigation polish.
- Current-node card polish using existing selected node data.
- Nodes selected-state/search/delay/empty/loading/error polish using existing live/cache node data.
- Hidden diagnostics via version 7 taps only.
- `safeNodeDisplayName` UI-only masking for all normal UI node labels.

### Map to Existing Service / Configuration
- Renewal / Upgrade buttons: in this rollout, open only the parsed UI/domain value `subscription.customerService`, which originates from backend `customer_service`. No fake payment screen, no hardcoded prices/plans/URLs. Any future renewal/order URL requires a separate field contract and separate plan.
- Customer support: existing configured customer-service launcher; backend field name may be `customer_service`, but UI code consumes `subscription.customerService` only.
- Privacy / Terms: existing local legal pages.
- Forgot password: this rollout removes/hides existing no-op `忘记密码` buttons unless a real reset URL/config already exists. Do not add a clickable forgot-password action, reset URL, or support URL in normal UI. **No empty `onPressed` and no hardcoded reset URL**.

### Proposal Only Until Real Source Exists
- Invite/referral: requires backend invite/referral URL and terms.
- Feedback form/submission: requires configured backend/email/customer-service destination; do not collect feedback into a dead local form.
- Official website/about link: requires trusted configured URL; do not hardcode `https://4376.net` unless product config supplies it.

### Forbidden in Normal UI
- Demo `SettingsScreen`, visible Settings label/page, advanced settings, Kill Switch, language/cache settings from demo.
- DNS, fake-ip, IPv6, route mode, protocol/core names, server/IP/domain/port/cipher, inbound ports, custom config.
- Subscription URL/import/copy/refresh actions in normal UI.
- XBoard/Hiddify/proxy core names in normal UI.
- Hardcoded fake nodes, fake payment plans/prices, fake invite link, fake website link, fake connection timer/state.

## Route Guidance
- Current route name `settings` is a **legacy internal wrapper** that renders Membership/UserProfile. It must not be presented as a normal Settings UI.
- Do not add visible Settings label/screen.
- Optional `/membership` route rename is a separate low-risk migration with redirects; it is not required for the first rollout unless visible UX is affected.
- Existing `goNamed('settings')` calls are acceptable only if they are internal redirects to Membership/login and never render a visible Settings page.

## Node Display-Name Safety Requirement
- Add one centralized UI-only helper at `lib/features/proxy/widget/safe_node_display_name.dart`, exposing `safeNodeDisplayName(String? value, {String fallback = '未命名节点'})` or equivalent.
- Add tests at `test/features/proxy/widget/safe_node_display_name_test.dart`.
- It must mask or replace:
  - `http://...`, `https://...`, `tg://...`, `mailto:...`, protocol-like prefixes,
  - IPv4 and IPv6-like literals,
  - domain names and domain:port forms,
  - obvious server-address-like strings,
  - overlong values that look like raw config fragments.
- It must fallback to `未命名节点` or `暂无可用节点`.
- It must **not** change node IDs, tags, outbounds, config, or selection/connection internals.
- Required call sites:
  - Android Home current node: `lib/features/home/widget/home_page.dart`,
  - Windows Home current node: `lib/features/home/widget/desktop_home_page.dart`,
  - Android Nodes live list/search: `lib/features/proxy/overview/proxies_overview_page.dart`,
  - Android proxy tile display: `lib/features/proxy/widget/proxy_tile.dart`,
  - Windows Nodes live/cache list/search: `lib/features/proxy/overview/desktop_nodes_page.dart`,
  - Windows tray current-node text: `lib/features/system_tray/notifier/system_tray_notifier.dart`.
- Nodes search matching must use sanitized display text.
- Existing local helpers such as `_safeNodeName` / `_safeTrayText` must be removed or delegated to the centralized helper to avoid divergent masking behavior.
- Static verification must show the helper is imported only by presentation/tray/search display files and not by `lib/features/proxy/model/client_node.dart`, `lib/features/proxy/data/client_node_store.dart`, profile/subscription parsers, outbound/core config generators, or connection internals.

## Forbidden-String Audit Rules
Audit user-visible strings across normal UI, tray, window titles, notifications, navigation, and membership/login/home/node files. Allowlist each hit explicitly as one of: `internal`, `diagnostics`, `legal`, `generated`, or `icon/constant`.

Allowlist examples:
- internal route/class names such as `settings`,
- icon constants,
- legal `用户协议`,
- generated translations not rendered in normal 4376 UI,
- diagnostics-only text,
- backend/internal API class names such as XBoard service/parser names.

Do **not** allow in normal UI:
- visible Settings / 设置 / 高级设置,
- XBoard / Hiddify / proxy core names,
- subscription URL/import/copy/refresh/sync actions, including `订阅URL` and `同步节点`,
- server/address/IP/domain/port/protocol/cipher, including `服务器`, `节点地址`, `域名`, `端口`, `协议`,
- DNS/fake-ip/IPv6/route mode/custom config,
- hardcoded fake nodes, fake payment/invite/website/demo URLs.

Required audit command baseline, expanded as needed by changed files. Keep it focused on normal UI/tray/navigation/resources and exclude import/export noise:
```bash
NORMAL_UI_PATHS=(
  lib/features/auth/widget
  lib/features/home/widget
  lib/features/proxy/overview
  lib/features/proxy/widget
  lib/features/system_tray
  lib/core/router
  lib/core/widget
  windows
  android/app/src/main/res
)
rg -n --pcre2 --glob "*.dart" --glob "*.xml" --glob "*.rc" \
  "(?i)(XBoard|Hiddify|订阅链接|订阅URL|导入订阅|复制订阅|刷新订阅|同步节点|subscribe_url|subscription URL|(?<![A-Za-z])(server|address|domain|host|port|protocol|cipher)(?![A-Za-z])|\bIP\b|\bIPv4\b|\bIPv6\b|服务器|节点地址|域名|端口|协议|DNS|dnsMode|fake-ip|fakeIp|route mode|routeMode|customConfig|\bSettings\b|设置|高级设置|Kill Switch|4376\.net|确认支付|邀请链接)" \
  "${NORMAL_UI_PATHS[@]}" | rg -v ":\s*(import|export)\s"
rg -n --pcre2 --glob "*.dart" "https?://|tg://|mailto:" \
  lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray
```
Normal UI means strings rendered in Home, Nodes, Membership/Login, bottom/side navigation, tray, notifications, window/title resources, and ordinary dialogs reachable without the hidden diagnostics gesture. Internal API names, generated translations not rendered in normal 4376 UI, icon constants, legal pages, and diagnostics-only output may be classified as allowlisted. Every hit must be recorded in the checklist classification table before completion. Forbidden normal-UI hits block the phase.

## Source and Path-Level Change Guard
This rollout must not modify service/backend/core/protocol behavior. Any change under the following paths requires a separate explicit plan/approval and must not be bundled into UI rollout commits:
- `lib/singbox/**`, `lib/hiddifycore/**`, `lib/features/connection/data/**`, `lib/features/connection/notifier/connection_notifier.dart` core/network/state-machine/start-stop internals,
- `lib/features/auth/data/login_service.dart`, XBoard API contract models/parsers except tests/documentation explicitly required for existing `customer_service` evidence,
- `lib/features/profile/data/**` subscription/profile parsing and generated config paths,
- `android/app/src/main/kotlin/**`, `android/app/src/main/aidl/**`, `android/app/src/main/protos/**`, Android VPN/TUN/service code,
- native Windows runner/network code under `windows/runner/**` unless the change is purely visual resource/name already covered by a separate branding task.

Required diff guard before every commit:
```bash
git diff --name-only -- . | rg -n "^(lib/(singbox|hiddifycore)|lib/features/(connection/data|connection/notifier|profile/data)|lib/features/auth/data/(login_service|xboard_response_parser|user_subscription_service)\.dart|android/app/src/main/(kotlin|aidl|protos)|windows/runner/)" || true
```
Any hit must be classified in the checklist as allowed-test/doc-only or blocker requiring separate approval.

## Customer-Service Source Boundary
- Normal UI can only consume `subscription.customerService` passed through existing auth/subscription state.
- Parser/service layers may populate that value from backend `customer_service`; UI widgets must not parse backend responses or define fallback support URLs.
- Membership/Login/Home/Nodes/tray code must not contain hardcoded `http://`, `https://`, `tg://`, `mailto:`, `4376.net`, or default customer-service URL strings.
- Existing launcher code may parse and launch the already-provided `subscription.customerService` value; missing value must show friendly feedback such as `客服暂未配置`.

## Phase Commit Evidence Gate
- Every completed modification phase must end with a git commit, even if the phase only changes planning/checklist files and requires `git add -f` because `.omx/` is ignored.
- Commit only files changed for the phase; do not stage unrelated dirty working-tree files.
- Commit messages must follow the Lore Commit Protocol from `AGENTS.md`.
- Checklist must record: phase number, commit hash, concise scope, Lore trailer summary, commands run, pass/fail result, and any documented blocker.
- A phase is not complete until the checklist contains its commit evidence.

## ADR

### Decision
Proceed with Option B: product-safe phased rollout. Use demo as the UI/interaction target for allowed surfaces and convert allowed actions to existing customer-service/legal/diagnostics flows. Defer or reject demo-only functions that lack real backend/config or violate normal UI safety.

### Drivers
- Need comprehensive demo advancement without fake production behavior.
- Must preserve 4376 commercial client compliance and secret-safety.
- Must avoid regressions in auth, node sync, selected node, connection, tray, and Windows network behavior.

### Alternatives Considered
- Literal clone: rejected for fake data/settings/security risks.
- UI-only polish: rejected for insufficient functionality progress.
- Hidden demo routes: rejected for maintenance and accidental exposure risk.
- Business-page-first expansion: deferred until renewal/invite/feedback/website/reset backend/config exists.

### Why Chosen
It delivers the maximum safe portion of demo UI/functionality now while creating explicit backlog/config contracts for unsupported demo functions.

### Consequences
- Some demo pages will not appear as pages in this pass.
- Renewal/Upgrade may continue to be customer-service actions until a real order URL/API exists.
- Internal route name `settings` may remain as compatibility wrapper but must not be visible.

### Follow-ups
- Define backend/config fields for renewal/order URL, invite/referral URL, feedback destination, official website, password reset.
- Consider `/membership` route migration with compatibility redirects.
- Add visual/golden tests after UI stabilizes.

## Phases

### Phase 0 — Checklist Artifact and Guardrail Inventory
Artifact: `.omx/plans/flutter-ui-demo-rollout-checklist.md`.

Tasks:
- Create checklist mapping every demo screen/function to: implement now / map to existing service / proposal only / forbidden.
- Record files touched per phase and deferred proposals.
- Confirm working tree status and baseline commit.
- Record forbidden-string audit allowlist.

Acceptance:
- Checklist exists and can be used by executors and reviewers.
- No production code changes required in this phase unless needed for documentation references.

Verification:
- `git status --short --ignore-submodules=all`
- Read checklist for all demo screens: Login, Main, Home, Nodes, Profile, Renewal, Invite, Feedback, Website, Settings.

Commit:
- Commit this planning/checklist phase with `git add -f .omx/plans/4376-flutter-ui-demo-ralplan.md .omx/plans/flutter-ui-demo-rollout-checklist.md` if `.omx/` is ignored.
- Record commit hash + Lore trailers + verification result in the checklist.

### Phase 1 — Shared Node Label Safety and Legacy Membership Route Guard
Touchpoints:
- `lib/features/proxy/widget/safe_node_display_name.dart` and `test/features/proxy/widget/safe_node_display_name_test.dart`.
- Android Home / Nodes, Windows Home / Nodes, tray notifier.
- `lib/core/router/go_router/routing_config_notifier.dart`, `my_adaptive_layout.dart`, `desktop_shell.dart`, connection button redirects only if visible route behavior needs cleanup.

Tasks:
- Add/reuse `safeNodeDisplayName` and apply to required call sites.
- Ensure search matching uses sanitized display text.
- Ensure tray current node uses sanitized display text.
- Verify legacy `/settings` only renders Membership/UserProfile and no visible Settings label/page.
- Replace/avoid visible Settings wording if present in normal UI.

Acceptance:
- No normal UI node label exposes IP/domain/server/port/protocol-like raw values.
- Navigation remains Home / Nodes / Membership.
- Logged-out connect targets Membership/login, not a visible Settings page.

Verification:
- `dart format --page-width 120 <changed files>`
- `dart analyze <changed files>`
- `flutter pub get && flutter analyze`
- Add/run targeted helper tests for `safeNodeDisplayName` masking URL, IPv4, IPv6, domain/domain:port, protocol-like prefix, raw config fragment, blank/overlong names, and normal friendly names.
- Static/diff check that `safeNodeDisplayName` is imported only by presentation/tray/search display code and is not used in `ClientNode.id`, selection storage, outbound tag, core config, or subscription parsing.
- User-visible forbidden audit with allowlist.

Commit after phase and record commit hash + Lore trailers + verification result in the checklist.

### Phase 2 — UI Parity Completion for Home / Nodes / Membership / Login
Touchpoints:
- `brand_theme.dart`, `brand_mark.dart`, `desktop_widgets.dart` as needed.
- `home_page.dart`, `connection_button.dart`, `desktop_home_page.dart`.
- `proxies_overview_page.dart`, `desktop_nodes_page.dart`, `proxy_tile.dart`.
- `user_profile_page.dart`, `desktop_membership_page.dart`.
- `my_adaptive_layout.dart`, `desktop_shell.dart` only for visual nav polish.

Tasks:
- Finish demo-like spacing, cards, typography, input/button styles, bottom nav polish, empty/loading/error states.
- Keep real providers/notifiers and existing behavior.
- Keep Windows fixed 390x910 shell.
- Do not add fake timer/state/data.

Acceptance:
- Android and Windows allowed pages visibly follow demo style.
- Existing login auto-sync, connection idempotency, selected node display, membership fields, customer-service/legal/diagnostics behavior unchanged.
- No forbidden normal UI content.

Verification:
- `dart format --page-width 120 <changed files>`
- `dart analyze <changed files>`
- `flutter pub get && flutter analyze`
- `flutter build apk --debug -t lib/main.dart` as Flutter Android build verification.
- If project release requires raw Gradle, run from `android/` or document blocker: `./gradlew assembleDebug`.
- `flutter build windows --release -t lib/main.dart` on Windows-capable runner.
- Manual smoke Android + Windows pages.

Commit after phase and record commit hash + Lore trailers + verification result in the checklist.

### Phase 3 — Safe Business Action Mapping
Touchpoints:
- Membership mobile/desktop pages.
- Existing customer-service opener and legal routes.
- No backend/API changes unless a real config field already exists.

Tasks:
- Ensure Renewal/Upgrade/Support use only parsed `subscription.customerService` from backend `customer_service` in this rollout; no hardcoded URL and no future renewal/order URL without a separate plan/field contract.
- Remove/hide the existing no-op Forgot Password buttons in mobile and desktop logged-out forms unless a real reset URL/config already exists; no empty no-op handlers and no hardcoded reset/support URL.
- Keep Privacy/Terms local pages and hidden diagnostics version tap.
- Do not add Invite/Feedback/Website forms/pages unless real destination/config exists; otherwise add proposal notes to checklist.

Acceptance:
- No fake payment/prices/plans/invite/website/reset/feedback data.
- No dead buttons in logged-out or membership UI.
- Missing service shows friendly feedback like “客服暂未配置”.

Verification:
- `dart format --page-width 120 <changed files>`
- `dart analyze <changed files>`
- `flutter pub get && flutter analyze`
- Android and Windows build checks if code changed.
- Manual smoke for renewal/upgrade/support/legal/logout/forgot-password behavior.

Commit after phase and record commit hash + Lore trailers + verification result in the checklist.

### Phase 4 — Final Compliance and Release-Readiness Sweep
Tasks:
- Run full visible-string audit with allowlist.
- Ensure no fake demo data remains in production `lib/` normal UI.
- Validate Android and Windows builds.
- Confirm each completed phase has a git commit.

Verification Commands:
```bash
flutter pub get && flutter analyze
dart analyze <changed files>
flutter build apk --debug -t lib/main.dart
# Optional/raw project Android command if required by release process:
# cd android && ./gradlew assembleDebug
# Windows-capable runner only:
flutter build windows --release -t lib/main.dart
NORMAL_UI_PATHS=(lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray lib/core/router lib/core/widget windows android/app/src/main/res)
rg -n --pcre2 --glob "*.dart" --glob "*.xml" --glob "*.rc" "(?i)(XBoard|Hiddify|订阅链接|订阅URL|导入订阅|复制订阅|刷新订阅|同步节点|subscribe_url|subscription URL|(?<![A-Za-z])(server|address|domain|host|port|protocol|cipher)(?![A-Za-z])|\bIP\b|\bIPv4\b|\bIPv6\b|服务器|节点地址|域名|端口|协议|DNS|dnsMode|fake-ip|fakeIp|route mode|routeMode|customConfig|\bSettings\b|设置|高级设置|Kill Switch|4376\.net|确认支付|邀请链接)" "${NORMAL_UI_PATHS[@]}" | rg -v ":\s*(import|export)\s"
rg -n --pcre2 --glob "*.dart" "https?://|tg://|mailto:" lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray
```
Audit hits must be manually classified as forbidden normal UI vs allowlisted internal/diagnostics/legal/generated/icon text.

## Execution Staffing
- Recommended: sequential execution (`$ralph` or direct sequential) because UI files overlap heavily.
- Team option only with strict write scopes:
  - Lane A: shared safety helpers + route/nav guard.
  - Lane B: Android allowed pages.
  - Lane C: Windows allowed pages/tray.
  - Lane D: audit/verification after integration.

## Stop Condition
Stop execution when:
- Checklist is updated,
- all implemented phases pass verification,
- no forbidden normal UI strings remain unclassified,
- Android build passes,
- Windows build passes or has a documented environment blocker,
- git commits exist for completed phases,
- deferred demo functions are listed as proposals with required backend/config sources.
