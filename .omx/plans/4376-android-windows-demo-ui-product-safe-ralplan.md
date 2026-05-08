# RALPLAN-DR: 4376 Android/Windows Demo UI Product-Safe Rollout

## Outcome
按照 `docs/flutter_ui_demo.dart` 的视觉与交互方向，落地 Android 与 Windows 的 4376 正常用户 UI，但只在产品安全边界内实现：普通 UI 仅包含 `Login / Home / Nodes / Membership`，另保留隐藏 Diagnostics；所有功能必须复用现有客户端状态、登录、节点缓存/同步、会员信息、客户服务和本地法律页面，不修改服务端、XBoard、节点后端、core 协议或连接状态机。

## Evidence Used
- Context snapshot: `.omx/context/4376-demo-ui-full-rollout-20260508T071922Z.md`。
- Existing plan: `.omx/plans/4376-flutter-ui-demo-ralplan.md`。
- Demo source exists at `docs/flutter_ui_demo.dart`。
- Current likely touchpoints from snapshot: Home, Nodes, Membership/Login, theme/widgets, system tray, hidden diagnostics, related tests。
- Current working tree is already very dirty; executors must not stage unrelated files and must record baseline status before each phase.

## Non-Negotiable Constraints
- Do **not** modify: server/XBoard API contract, Xboard-Node backend, core protocol/config generation, native VPN/TUN implementation, or connection state machine/start-stop internals.
- Do **not** show in normal UI: subscription link/URL/import/copy/refresh/sync, IP, port, protocol, server address/domain, DNS, fake-ip, IPv6, route mode, cipher, core/proxy technical names, XBoard/Hiddify names, advanced/custom config.
- Do **not** log or expose in diagnostics full tokens, subscribe URLs, node passwords, full server addresses, or raw technical node labels. Any `selectedNodeName`/node-label diagnostic must pass the same display-safe sanitizer used by UI/tray.
- Normal UI routes/pages: `Home`, `Nodes`, `Membership`, `Login`; hidden Diagnostics only via existing hidden gesture/route.
- `Invite / Feedback / Website / ForgotPassword / Payment` have no reliable real backend field in the provided evidence. They must be deferred as “待接入” or mapped only to configured `subscription.customerService` where the action meaning is support/customer-service.
- No hardcoded production secrets, authData, tokens, subscribe URLs, node credentials, customer-service URLs, fake payment plans, fake invite links, fake website URLs, or demo nodes.
- Every implementation phase starts by listing files to change, ends with formatter/analyze/build or documented blocker, and is committed with Lore commit trailers.

## RALPLAN-DR

### Principles
1. **Demo is a design catalog, not a data source**: copy layout, hierarchy, spacing, card style, and safe interactions; never copy fake `VpnState`, hardcoded nodes, hardcoded plans, payment, invite, website, or settings behavior.
2. **Product safety beats visual completeness**: if a demo element exposes technical/network details or unsupported business flows, it is hidden, renamed, mapped to customer service, or deferred.
3. **Real state only**: Login, node list, selected node, connection status, traffic/membership values, tray state, and support actions must come from existing production providers/state.
4. **Contain blast radius**: UI rollout is limited to presentation, route labels, safe display masking, local legal/diagnostic entry points, tests, and docs/checklists.
5. **Phase-gated evidence**: each phase produces a small commit with explicit verification output and a forbidden-string/secret-safety audit before claiming completion.
6. **One sanitizer boundary**: UI, tray, search, logs, and diagnostics share one presentation/log-safe node-label sanitizer; IDs, outbound tags, selected-node storage, parsers, and core config never use display labels.

### Decision Drivers — Top 3
1. The user wants Android and Windows UI to match `docs/flutter_ui_demo.dart` while including “上面的功能”, so the plan must cover both visual parity and allowed functionality.
2. 4376 compliance rules forbid normal UI exposure of subscription, server, protocol, DNS, fake-ip, IPv6, route, settings, and backend/core implementation details.
3. Existing auth/node/connection/tray behavior is already production-critical; UI work must not regress login auto-sync, cached nodes, selected node, one-click connect, idempotent core start/stop, or Windows tray behavior.

### Viable Options

#### Option A — Literal demo clone
- Approach: port all screens/actions from `docs/flutter_ui_demo.dart` into Android/Windows UI.
- Pros: highest superficial demo parity and fastest visible breadth.
- Cons: would introduce fake local state/data, fake payment/invite/website/feedback, visible Settings, and likely forbidden technical or unsupported flows.
- Decision: **Rejected** because it violates product safety and backend/source-of-truth constraints.

#### Option B — Product-safe phased rollout
- Approach: implement demo visual language only on allowed pages; map allowed actions to existing real services; defer unsupported actions with explicit backend/config requirements.
- Pros: satisfies UI direction while preserving auth, node sync, connection, tray, and compliance constraints; easiest to verify and commit safely.
- Cons: not every demo screen becomes a normal page; some functions remain “待接入”.
- Decision: **Chosen**.

#### Option C — UI-only polish without functionality mapping
- Approach: update colors/cards/spacing only, avoid business action changes.
- Pros: lowest implementation risk.
- Cons: under-delivers “包括上面的功能” and leaves unsupported/no-op buttons ambiguous.
- Decision: **Rejected as incomplete**, but useful as a fallback if Phase 3 uncovers blockers.

#### Option D — Internal demo/preview routes behind diagnostics
- Approach: keep demo screens as hidden preview pages.
- Pros: designers can compare demo parity without exposing normal users.
- Cons: still risks stale fake data, accidental exposure, and maintenance burden.
- Decision: **Deferred**; only consider under a separate internal-tooling plan.

## Decision / ADR

### Decision
Proceed with Option B: product-safe phased rollout for Android and Windows. Treat `docs/flutter_ui_demo.dart` as the UI reference for allowed surfaces, while preserving current backend/core/connectivity contracts and deferring unsupported business pages.

### Drivers
- Deliver user-visible demo-style UI on both platforms.
- Maintain 4376 safety/compliance and secret hygiene.
- Avoid regressions in existing auth, node cache/sync, selected node, connection state, and tray behavior.

### Alternatives Considered
- Literal clone: rejected for fake/forbidden flows.
- UI-only polish: rejected for insufficient functionality coverage.
- Hidden demo routes: deferred as separate internal-preview scope.

### Why Chosen
It maximizes safe delivery now: Login/Home/Nodes/Membership can look and feel like the demo while only using real client state and customer-service/legal/diagnostic mechanisms already present.

### Consequences
- Invite, Feedback, Website, ForgotPassword, and Payment are not normal UI pages/actions unless a real backend/config field is added later.
- Renewal/Upgrade/Support actions can only open configured `subscription.customerService` or show a friendly “客服暂未配置” state.
- Internal legacy route name/path `settings` may remain only as a compatibility wrapper or redirect to Membership; normal user labels must not say Settings/设置 and `/settings` must not render advanced settings.
- Log/diagnostic node label output is part of the safety surface and must be sanitized alongside UI/tray text.

### Follow-ups
- Define backend/config contracts for renewal/order URL, referral/invite URL, feedback destination, official website URL, and password-reset URL if product wants these as direct actions.
- Consider a later route cleanup from legacy `settings` naming to `membership` with redirects, if needed.
- Add visual/golden regression tests after layouts stabilize.

## File Scope

### Allowed primary UI scope
- Demo/reference/docs: `docs/flutter_ui_demo.dart`, `.omx/plans/**`.
- Theme/shared widgets: `lib/core/theme/brand_theme.dart`, `lib/core/widget/brand_mark.dart`, `lib/core/widget/desktop/desktop_widgets.dart`.
- Routing/shell labels only if needed: `lib/core/router/**`, `lib/core/router/adaptive_layout/**`.
- Login/Membership: `lib/features/auth/widget/user_profile_page.dart`, `lib/features/auth/widget/desktop_membership_page.dart`, related auth UI widgets if present.
- Home/connect UI: `lib/features/home/widget/home_page.dart`, `lib/features/home/widget/desktop_home_page.dart`, `lib/features/home/widget/connection_button.dart`.
- Nodes UI: `lib/features/proxy/overview/proxies_overview_page.dart`, `lib/features/proxy/overview/desktop_nodes_page.dart`, `lib/features/proxy/widget/proxy_tile.dart`.
- Safe display/log helper/tests: prefer neutral utility path `lib/features/proxy/utils/node_label_sanitizer.dart` plus compatibility wrapper if needed at `lib/features/proxy/widget/safe_node_display_name.dart`; tests under `test/features/proxy/**`.
- Presentation/log call sites for sanitized node labels only: Home/Nodes/ProxyTile/tray, `lib/features/auth/notifier/auth_notifier.dart` diagnostic node summaries, and `lib/features/proxy/data/client_node_store.dart` log summaries. These notifier/store changes are allowed only for log text sanitization, not state/storage behavior.
- Tray text only: `lib/features/system_tray/notifier/system_tray_notifier.dart`.
- Hidden diagnostics UI only when preserving/confirming access: `lib/features/diagnostics/**`.
- Platform visual resources only if required by UI brand parity: `android/app/src/main/res/**`, Windows non-network title/tray visual resources; avoid `windows/runner/**` unless purely pre-approved visual metadata.

### Blocked unless a separate explicit plan approves it
- `lib/singbox/**`, `lib/hiddifycore/**`.
- `lib/features/connection/data/**`, `lib/features/connection/model/**`, `lib/features/connection/notifier/**`, and `lib/features/connection/widget/**` for state-machine/start-stop/permission/status internals. UI work may edit `lib/features/home/widget/connection_button.dart` only, because it is a Home presentation wrapper, not the connection state machine.
- `lib/features/auth/data/login_service.dart` and XBoard API contract/parser behavior, except read-only evidence or tests proving existing `customer_service` mapping.
- `lib/features/proxy/data/**` except the explicit `client_node_store.dart` log-only sanitizer call above; no node storage/selection behavior changes.
- `lib/features/profile/data/**` profile/subscription parser or config generation behavior.
- `android/app/src/main/kotlin/**`, `android/app/src/main/aidl/**`, `android/app/src/main/protos/**`.
- Native Windows network/TUN/core behavior under `windows/runner/**`.

## Functional Mapping Rules

| Demo/Requested Function | Product-safe handling |
| --- | --- |
| Login | Keep existing real login/auth restore; demo-style visuals only. On login success, existing auto sync from `subscribe_url` remains unchanged. |
| Home one-click connect | Use existing connection provider/state machine only. UI can improve card/button states but must not fake connection status/timer. |
| Current selected node | Show sanitized friendly node name only; no address/IP/protocol/port. Use existing selected-node/cache state. |
| Nodes page | Use existing live/cache node data; sanitize display/search labels; no subscription URL/sync/import controls in normal UI. |
| Membership usage/expiry | Use existing membership/subscription state; demo-style cards allowed. Unknown values show safe empty/unknown states. |
| Renewal/Upgrade/Support | Open existing configured `subscription.customerService` only, or show “客服暂未配置”. No hardcoded URL/payment page/prices. |
| Privacy/Terms | Use existing local legal pages. |
| Hidden Diagnostics | Preserve hidden entry only; diagnostics may show technical data only outside normal UI and still must sanitize secrets. |
| Invite/Referral | 待接入: requires backend/config referral URL and terms. Do not implement normal UI action now. |
| Feedback | 待接入 or map to customer service if product accepts support contact as feedback destination. No dead local form. |
| Website/About | 待接入: requires trusted configured URL. Do not hardcode website. |
| Forgot Password | 待接入: requires real reset URL/API. Hide or non-clickable explanatory support path only via customer service; no no-op button. |
| Payment/Plan purchase | 待接入 or customer-service mapping. No fake plans/prices/payment confirmation. |
| Settings/Kill Switch/technical settings | Forbidden in normal UI. |


## Audit and Route Boundary Policy

### Blocking forbidden-string audit
The rollout must not rely on `rg ... || true` as the final gate. Each phase may use exploratory `rg` commands, but completion requires a blocking audit step:
1. Write raw audit output to `.omx/logs/<phase>-forbidden-audit.txt` (or equivalent ignored artifact).
2. Classify every hit in the checklist as `normal-ui-blocker`, `internal`, `diagnostics`, `legal`, `generated`, or `icon/constant`.
3. If any unclassified hit or `normal-ui-blocker` remains, the phase fails and must not be committed as complete.
4. Test literals such as `example.com` are allowed only in test files and must be classified.

Suggested gate pattern:
```bash
# exploratory collection is allowed to return hits
rg ... > .omx/logs/phase-N-forbidden-audit.txt || true
# completion gate: scripted failure if any hit is not classified in checklist
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-N-forbidden-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
```
Phase 0 must add a real gate helper at `scripts/verify_forbidden_audit_classified.py` (or an equivalent checked-in script) that reads the raw audit file and checklist allowlist, then exits non-zero when any raw hit is missing from the checklist or classified as `normal-ui-blocker`. Manual review alone is not sufficient after Phase 0; raw `rg ... || true` collection is allowed only when immediately followed by this blocking script gate in the same verification block.


### Required forbidden audit terms
The audit pattern must include the existing technical/subscription terms plus these demo/product-safety terms:
`全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护|4376 VPN`.

`4376 VPN` is audited because the user-visible product name should be `4376`; legal/privacy prose may mention VPN-style service only if classified as legal or product-description text, not as a brand name.

### `settings` / Membership route boundary
Minimum acceptable execution path:
- Visible navigation labels and normal user page titles use `会员` / `Membership`, not `设置` / `Settings`.
- Existing `settings` route name/path may remain only as an internal compatibility wrapper that renders Membership/Login, or it may redirect to a new `membership` route.
- `/settings` must not show advanced settings and must not expose DNS/TUN/fake-ip/IPv6/route/custom config.
- Any external/deep link to `/settings` must land on Membership/Login, not a technical settings page.

Preferred cleanup if low risk:
- Add `membership` route name/path for new code.
- Keep `settings -> membership` redirect for compatibility.
- Update connect/login redirects to `membership` while preserving old route compatibility.

## Phases

### Phase 0 — Baseline, Checklist, and Scope Lock
**Goal:** Create execution guardrails before code changes.

**Expected files:**
- `.omx/plans/flutter-ui-demo-rollout-checklist.md` or update existing checklist.
- `.omx/logs/phase-0-forbidden-audit.txt` as ignored/raw evidence if audit is run.
- `scripts/verify_forbidden_audit_classified.py` blocking audit helper.
- This plan file if not already committed.

**Steps:**
1. Record current `git status --short --ignore-submodules=all`; note existing unrelated dirty files.
2. Create/update checklist mapping every demo screen/action to `implement / customer_service mapping / 待接入 / forbidden`.
3. Record exact planned files for Phase 1 before editing.
4. Add forbidden-string allowlist table categories: `normal-ui-blocker`, `internal`, `diagnostics`, `legal`, `generated`, `icon/constant`.
5. Add `scripts/verify_forbidden_audit_classified.py`: it must parse raw `rg` output lines, match each line against checklist entries, and exit non-zero for unclassified hits or any entry classified `normal-ui-blocker`.
6. Document the canonical forbidden regex including `全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护|4376 VPN`.

**Acceptance:**
- Checklist exists and explicitly classifies Login, Home, Nodes, Membership/Profile, Renewal, Invite, Feedback, Website, ForgotPassword, Payment, Settings.
- No production code changes in Phase 0.
- Existing dirty working tree is documented so later commits do not accidentally include unrelated files.

**Verification commands:**
```bash
git status --short --ignore-submodules=all
git diff --name-only -- .omx/plans scripts/verify_forbidden_audit_classified.py
python3 scripts/verify_forbidden_audit_classified.py --self-test
```

**Commit requirement:**
- Commit only the plan/checklist/script files, using `git add -f` for `.omx/` if ignored.
- Lore message must include `Constraint: planning-only`, `Tested: git status + plan/checklist review`, and `Not-tested: no production build because no code changed`.

### Phase 1 — Shared Node Label Sanitizer, Log/Diagnostics Sanitization, and Navigation Guard
**Goal:** Prevent normal UI/tray/search/logs/diagnostics from exposing server identifiers while confirming visible navigation remains Home/Nodes/Membership/Login.

**Expected files:**
- `lib/features/proxy/utils/node_label_sanitizer.dart` or `lib/features/proxy/widget/safe_node_display_name.dart` compatibility wrapper
- `test/features/proxy/widget/safe_node_display_name_test.dart` and/or `test/features/proxy/utils/node_label_sanitizer_test.dart`
- `lib/features/home/widget/home_page.dart`
- `lib/features/home/widget/desktop_home_page.dart`
- `lib/features/proxy/overview/proxies_overview_page.dart`
- `lib/features/proxy/overview/desktop_nodes_page.dart`
- `lib/features/proxy/widget/proxy_tile.dart`
- `lib/features/system_tray/notifier/system_tray_notifier.dart`
- Router/shell files only if visible Settings labels/routes need cleanup or if adding a `membership` route redirect.
- Route/widget tests such as `test/core/router/membership_route_boundary_test.dart` or equivalent.
- `lib/features/auth/notifier/auth_notifier.dart` and `lib/features/proxy/data/client_node_store.dart` only for log/diagnostic label sanitization, not behavior changes.

**Steps:**
1. Before editing, list exact files to change.
2. Add/reuse centralized node-label sanitizer for UI/tray/search/log/diagnostic display only.
3. Mask URLs, protocol-like prefixes, IPv4/IPv6 literals, domains/domain:port, server-like raw fragments, and overlong config-like values.
4. Apply helper to Android Home, Windows Home, Android Nodes, Windows Nodes, proxy tile, tray current-node text, and diagnostic/log strings that include `selectedNodeName` or node labels.
5. Ensure search matches sanitized display names; do not change node IDs, tags, selected-node keys, outbound tags, or core config.
6. Remove/delegate divergent local safe-name helpers.
7. Add a route/widget boundary test proving `/settings` and logged-out connect land on Membership/Login and do not render `设置`, `Settings`, `DNS`, `TUN`, `fake-ip`, `IPv6`, `高级设置`, or `Kill Switch`.
8. If route cleanup is included, add/verify `membership` as the normal route and keep `settings` only as redirect/compatibility wrapper.
9. Confirm visible nav labels are Home / Nodes / Membership; no visible Settings page.

**Acceptance:**
- Normal UI/tray/search/logs/diagnostics never display raw IP/domain/port/protocol-like node names.
- Sanitization is presentation-only; connection/selection internals remain unchanged.
- The sanitizer is not used for node IDs, selectedNodeId storage, outbound tags, parsers, core config, or connection internals; `client_node_store.dart` use is log-only if touched.
- Logged-out connect/navigation does not expose a visible Settings page; `/settings` compatibility route renders/redirects to Membership/Login only, proven by a route/widget test.

**Verification commands:**
```bash
dart format --page-width 120 <changed files>
flutter test test/features/proxy/widget/safe_node_display_name_test.dart
flutter test test/core/router/membership_route_boundary_test.dart  # or the actual route-boundary test path added in this phase
# plus any new sanitizer/log tests added in this phase; these are blocking and must not use || true
flutter pub get && flutter analyze
rg -n "safeNodeDisplayName" lib test
# Verify sanitizer usage is presentation/log-only, never parser/core/connection/tag behavior.
rg -n "nodeLabelSanitizer|safeNodeDisplayName|sanitizeNodeLabel" lib test
NORMAL_UI_PATHS=(lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray lib/core/router lib/core/widget)
rg -n --pcre2 --glob "*.dart" "(?i)(XBoard|Hiddify|订阅链接|订阅URL|导入订阅|复制订阅|刷新订阅|同步节点|subscribe_url|subscription URL|(?<![A-Za-z])(server|address|domain|host|port|protocol|cipher)(?![A-Za-z])|\bIP\b|\bIPv4\b|\bIPv6\b|服务器|节点地址|域名|端口|协议|DNS|dnsMode|fake-ip|fakeIp|route mode|routeMode|customConfig|\bSettings\b|设置|高级设置|Kill Switch|4376\.net|4376 VPN|确认支付|邀请链接|全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护)" "${NORMAL_UI_PATHS[@]}" | rg -v ":\s*(import|export)\s" > .omx/logs/phase-1-forbidden-audit.txt || true
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-1-forbidden-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
# Blocking diff guard: command must succeed only when no blocked-path changes exist.
! git diff --name-only -- . | rg -n "^(lib/(singbox|hiddifycore)|lib/features/(connection/data|connection/model|connection/notifier|connection/widget|profile/data)|lib/features/auth/data/(login_service|xboard_response_parser|user_subscription_service)\.dart|android/app/src/main/(kotlin|aidl|protos)|windows/runner/)"
# Before commit, classify all audit/diff hits in checklist; unclassified or normal-ui-blocker hits fail the phase.
```

**Commit requirement:**
- Commit only Phase 1 files.
- Lore trailers: `Constraint: display-only masking`, `Rejected: data/model/core-level mutation`, `Tested: helper tests + flutter analyze + diff guard`, `Not-tested: platform builds unless run in this phase`.

### Phase 2 — Android UI Parity on Allowed Pages
**Goal:** Bring Android Login/Home/Nodes/Membership closer to demo while keeping real providers and allowed actions only.

**Expected files:**
- `lib/core/theme/brand_theme.dart`
- `lib/core/widget/brand_mark.dart`
- `lib/features/auth/widget/user_profile_page.dart`
- `lib/features/home/widget/home_page.dart`
- `lib/features/home/widget/connection_button.dart`
- `lib/features/proxy/overview/proxies_overview_page.dart`
- `lib/features/proxy/widget/proxy_tile.dart`
- Android visual resources only if needed: `android/app/src/main/res/**`.

**Steps:**
1. Before editing, list exact files to change.
2. Apply demo-style visual hierarchy: branded header, rounded cards, spacing, typography, button states, empty/loading/error states.
3. Keep Login backed by existing auth flow; preserve startup auth restore before connect button enablement.
4. Keep Home backed by existing connection state; no fake timer/status.
5. Keep Nodes backed by existing live/cache nodes; no import/sync/subscription UI.
6. Keep Membership backed by existing subscription/traffic/expiry/customer-service/legal data.
7. Remove or hide no-op/demo-only actions unless mapped to `subscription.customerService`.

**Acceptance:**
- Android normal UI pages visually follow demo direction.
- Only Login/Home/Nodes/Membership are normal user surfaces.
- Membership traffic/expiry fields use real state or safe empty states.
- No forbidden strings/actions appear in normal Android UI.

**Verification commands:**
```bash
dart format --page-width 120 <changed files>
flutter pub get && flutter analyze
flutter build apk --debug -t lib/main.dart
(cd android && ./gradlew assembleDebug)
NORMAL_UI_PATHS=(lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/core/router lib/core/widget android/app/src/main/res)
rg -n --pcre2 --glob "*.dart" --glob "*.xml" "(?i)(XBoard|Hiddify|订阅链接|订阅URL|导入订阅|复制订阅|刷新订阅|同步节点|subscribe_url|subscription URL|(?<![A-Za-z])(server|address|domain|host|port|protocol|cipher)(?![A-Za-z])|\bIP\b|\bIPv4\b|\bIPv6\b|服务器|节点地址|域名|端口|协议|DNS|dnsMode|fake-ip|fakeIp|route mode|routeMode|customConfig|\bSettings\b|设置|高级设置|Kill Switch|4376\.net|4376 VPN|确认支付|邀请链接|全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护)" "${NORMAL_UI_PATHS[@]}" | rg -v ":\s*(import|export)\s" > .omx/logs/phase-2-forbidden-audit.txt || true
rg -n --pcre2 --glob "*.dart" "https?://|tg://|mailto:" lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget > .omx/logs/phase-2-url-audit.txt || true
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-2-forbidden-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-2-url-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
! git diff --name-only -- . | rg -n "^(lib/(singbox|hiddifycore)|lib/features/(connection/data|connection/model|connection/notifier|connection/widget|profile/data)|lib/features/auth/data/(login_service|xboard_response_parser|user_subscription_service)\.dart|android/app/src/main/(kotlin|aidl|protos)|windows/runner/)"
```

**Commit requirement:**
- Commit only Phase 2 Android UI files.
- Do not commit if forbidden audit has unclassified hits or any normal-ui-blocker.

- Lore trailers: `Constraint: Android normal UI only`, `Rejected: demo fake state/payment/settings`, `Tested: flutter analyze + debug APK + forbidden-string audit`, `Not-tested: Windows build unless run separately`.

### Phase 3 — Windows UI Parity, Tray Text, and Desktop Shell Polish
**Goal:** Bring Windows Login/Home/Nodes/Membership/tray-visible text in line with the demo style and 4376 rules.

**Expected files:**
- `lib/core/widget/desktop/desktop_widgets.dart`
- `lib/features/auth/widget/desktop_membership_page.dart`
- `lib/features/home/widget/desktop_home_page.dart`
- `lib/features/proxy/overview/desktop_nodes_page.dart`
- `lib/features/system_tray/notifier/system_tray_notifier.dart`
- Desktop shell/adaptive layout files only for visible nav polish.
- Windows visual title/resource files only if already in scope and not network/core behavior.

**Steps:**
1. Before editing, list exact files to change.
2. Apply demo-style desktop/mobile-shell parity: card spacing, selected node card, bottom/side nav polish, loading/empty/error states.
3. Keep Windows tray menu as `4376`, `Connect/Disconnect`, `Current node`, `Open app`, `Quit`, with sanitized current-node text.
4. Keep minimize-to-tray and notification naming behavior unchanged except visible branding if needed.
5. Do not expose diagnostics, technical settings, subscription URL, server details, or route/core terms in normal desktop UI.

**Acceptance:**
- Windows normal UI matches the allowed Android/demo style and uses only allowed pages.
- Tray text is 4376-branded and sanitized.
- No Windows core/network/native behavior changes.
- Windows build passes or has a documented environment blocker.

**Verification commands:**
```bash
dart format --page-width 120 <changed files>
flutter pub get && flutter analyze
flutter build windows --release -t lib/main.dart
# Run widget/unit tests added by rollout, including sanitizer, route label, and customer-service URI tests.
flutter test test/features/proxy test/features/auth
NORMAL_UI_PATHS=(lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray lib/core/router lib/core/widget windows)
rg -n --pcre2 --glob "*.dart" --glob "*.xml" --glob "*.rc" "(?i)(XBoard|Hiddify|订阅链接|订阅URL|导入订阅|复制订阅|刷新订阅|同步节点|subscribe_url|subscription URL|(?<![A-Za-z])(server|address|domain|host|port|protocol|cipher)(?![A-Za-z])|\bIP\b|\bIPv4\b|\bIPv6\b|服务器|节点地址|域名|端口|协议|DNS|dnsMode|fake-ip|fakeIp|route mode|routeMode|customConfig|\bSettings\b|设置|高级设置|Kill Switch|4376\.net|4376 VPN|确认支付|邀请链接|全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护)" "${NORMAL_UI_PATHS[@]}" | rg -v ":\s*(import|export)\s" > .omx/logs/phase-3-forbidden-audit.txt || true
rg -n --pcre2 --glob "*.dart" "https?://|tg://|mailto:" lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray > .omx/logs/phase-3-url-audit.txt || true
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-3-forbidden-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-3-url-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
! git diff --name-only -- . | rg -n "^(lib/(singbox|hiddifycore)|lib/features/(connection/data|connection/model|connection/notifier|connection/widget|profile/data)|lib/features/auth/data/(login_service|xboard_response_parser|user_subscription_service)\.dart|android/app/src/main/(kotlin|aidl|protos)|windows/runner/)"
```

**Commit requirement:**
- Commit only Phase 3 Windows/tray files.
- Do not commit if forbidden audit has unclassified hits or any normal-ui-blocker.

- Lore trailers: `Constraint: Windows normal UI/tray only`, `Rejected: native network/core changes`, `Tested: flutter analyze + windows release build + forbidden-string audit`, `Not-tested: Android build unless rerun`.

### Phase 4 — Business Action Cleanup and Deferred Function Register
**Goal:** Resolve demo-only functions safely so no fake/dead normal UI actions remain.

**Expected files:**
- `lib/features/auth/widget/user_profile_page.dart`
- `lib/features/auth/widget/desktop_membership_page.dart`
- Local legal route/page files only if linking existing Privacy/Terms.
- `.omx/plans/flutter-ui-demo-rollout-checklist.md`

**Steps:**
1. Before editing, list exact files to change.
2. Ensure Renewal/Upgrade/Support use only existing `subscription.customerService`; missing value shows friendly feedback.
3. Remove/hide no-op Forgot Password action unless a real reset URL/API is already available through existing state/config; do not add a hardcoded reset URL.
4. Keep Privacy/Terms as local legal pages.
5. Register Invite, Feedback, Website, ForgotPassword, Payment as `待接入` unless mapped to customer service with product-approved wording.
6. Do not add new backend parsing fields in this rollout.

**Acceptance:**
- No fake payment, plan price, invite, website, feedback submission, or password reset flow appears in normal UI.
- Support/renewal actions fail safely when `customerService` is absent.
- Deferred items list required future source fields/contracts.

**Verification commands:**
```bash
dart format --page-width 120 <changed files>
flutter pub get && flutter analyze
flutter build apk --debug -t lib/main.dart
(cd android && ./gradlew assembleDebug)
flutter build windows --release -t lib/main.dart
rg -n --pcre2 --glob "*.dart" "确认支付|邀请链接|忘记密码|找回密码|Feedback|Invite|Website|4376\.net|4376 VPN|https?://|tg://|mailto:" lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray > .omx/logs/phase-4-business-audit.txt || true
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-4-business-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
! git diff --name-only -- . | rg -n "^(lib/(singbox|hiddifycore)|lib/features/(connection/data|connection/model|connection/notifier|connection/widget|profile/data)|lib/features/auth/data/(login_service|xboard_response_parser|user_subscription_service)\.dart|android/app/src/main/(kotlin|aidl|protos)|windows/runner/)"
```

**Commit requirement:**
- Commit only Phase 4 business-action UI/checklist files.
- Do not commit if business-action/URL audit has unclassified hits or any normal-ui-blocker.

- Lore trailers: `Constraint: no real backend field for deferred actions`, `Rejected: hardcoded URLs/payment/no-op reset`, `Tested: flutter analyze + Android/Windows builds + business-action audit`.

### Phase 5 — Final Compliance, Build, and Release Readiness Sweep
**Goal:** Prove the rollout is complete and safe to hand off/release.

**Expected files:**
- `.omx/plans/flutter-ui-demo-rollout-checklist.md`
- No new code unless fixing audit failures from prior phases.

**Steps:**
1. Confirm every completed phase has a git commit hash and Lore trailer summary in the checklist.
2. Run full forbidden-string audit and classify every hit.
3. Run full formatter/analyze/build verification.
4. Run manual smoke checklist for Android and Windows.
5. Document remaining deferred functions and backend/config contracts.

**Acceptance:**
- No unclassified forbidden normal-UI hits.
- No changes under blocked service/core/native paths unless separately approved and documented.
- Android debug build passes.
- Windows release build passes or environment blocker is explicit and reproducible.
- Manual smoke confirms Login, Home, Nodes, Membership, tray, hidden Diagnostics, legal/customer-service states.

**Verification commands:**
```bash
git status --short --ignore-submodules=all
flutter pub get && flutter analyze
flutter build apk --debug -t lib/main.dart
(cd android && ./gradlew assembleDebug)
flutter build windows --release -t lib/main.dart
# Run widget/unit tests added by rollout, including sanitizer, route label, and customer-service URI tests.
flutter test test/features/proxy test/features/auth
NORMAL_UI_PATHS=(lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray lib/core/router lib/core/widget windows android/app/src/main/res)
rg -n --pcre2 --glob "*.dart" --glob "*.xml" --glob "*.rc" "(?i)(XBoard|Hiddify|订阅链接|订阅URL|导入订阅|复制订阅|刷新订阅|同步节点|subscribe_url|subscription URL|(?<![A-Za-z])(server|address|domain|host|port|protocol|cipher)(?![A-Za-z])|\bIP\b|\bIPv4\b|\bIPv6\b|服务器|节点地址|域名|端口|协议|DNS|dnsMode|fake-ip|fakeIp|route mode|routeMode|customConfig|\bSettings\b|设置|高级设置|Kill Switch|4376\.net|4376 VPN|确认支付|邀请链接|全局代理|智能分流|路由设置|代理模式|所有流量|VPN意外断开|断网保护)" "${NORMAL_UI_PATHS[@]}" | rg -v ":\s*(import|export)\s" > .omx/logs/phase-5-forbidden-audit.txt || true
rg -n --pcre2 --glob "*.dart" "https?://|tg://|mailto:" lib/features/auth/widget lib/features/home/widget lib/features/proxy/overview lib/features/proxy/widget lib/features/system_tray > .omx/logs/phase-5-url-audit.txt || true
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-5-forbidden-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
python3 scripts/verify_forbidden_audit_classified.py .omx/logs/phase-5-url-audit.txt .omx/plans/flutter-ui-demo-rollout-checklist.md
! git diff --name-only -- . | rg -n "^(lib/(singbox|hiddifycore)|lib/features/(connection/data|connection/model|connection/notifier|connection/widget|profile/data)|lib/features/auth/data/(login_service|xboard_response_parser|user_subscription_service)\.dart|android/app/src/main/(kotlin|aidl|protos)|windows/runner/)"
```

**Commit requirement:**
- If Phase 5 changes only checklist/audit docs, commit only those files with `git add -f` as needed.
- Lore trailers: `Constraint: final compliance evidence`, `Tested: full analyze + Android/Windows builds + audits`, `Not-tested: any unavailable platform check with reason`.

## Manual Smoke Checklist
- Android: Login screen, auth failure/loading/success states, Home connect/disconnect display, selected node display, Nodes loading/empty/error/selected/search, Membership traffic/expiry/support/legal/logout.
- Windows: fixed shell/page layout, Home connect/disconnect display, Nodes selection/search/cache state, Membership customer-service/legal/logout, tray menu labels and sanitized current node, minimize/open/quit behavior.
- Hidden Diagnostics: still hidden; access path works; no secrets displayed.
- Safety: no subscription URL, IP/domain/port/protocol/DNS/fake-ip/IPv6/route/settings text in normal UI.
- Route boundary: `/settings` or legacy settings route opens Membership/Login only or redirects to `/membership`; no advanced settings are reachable from normal UI.

## Team / Handoff Guidance
- Recommended execution mode: sequential `ralph` or one executor, because Android/Windows UI files overlap and require careful audit.
- If using `team`, keep write scopes disjoint:
  - Lane A (`executor`, medium reasoning): safe node display helper/tests and navigation label guard.
  - Lane B (`executor`, medium reasoning): Android Login/Home/Nodes/Membership UI only.
  - Lane C (`executor`, medium reasoning): Windows desktop pages/tray text only.
  - Lane D (`verifier`, high reasoning): audits, builds, checklist evidence; read-only until fixes are assigned.
- Team launch hint: `$team "Execute .omx/plans/4376-android-windows-demo-ui-product-safe-ralplan.md phase-by-phase; do not modify blocked backend/core/native paths; commit each phase with Lore trailers."`
- Ralph launch hint: `$ralph "Execute .omx/plans/4376-android-windows-demo-ui-product-safe-ralplan.md sequentially; stop after each phase commit if verification fails."`

## Risks and Mitigations
- **Dirty working tree risk:** use `git status` and targeted `git add <phase files>` only; never broad-stage.
- **Forbidden detail leakage:** centralize node display masking and run forbidden-string audits each phase.
- **Fake/demo action creep:** maintain deferred-function register; reject hardcoded URLs/payment/no-op actions.
- **Regression in connection/auth:** keep providers/state machines untouched; use UI-only changes and build/analyze checks.
- **Platform build gap:** if Windows build cannot run in the current environment, document exact command failure and require Windows-capable verification before release.

## Stop Condition
Stop when all selected implementation phases have commits, checklist evidence is current, audits have no unclassified normal-UI blockers, Android build passes, Windows build passes or has a documented environment blocker, and Invite/Feedback/Website/ForgotPassword/Payment remain deferred or customer-service-mapped without hardcoded data.
