import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';
import 'package:hiddify/features/log/model/log_entity.dart';
import 'package:hiddify/features/log/overview/logs_overview_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DesktopDiagnosticsPage extends HookConsumerWidget {
  const DesktopDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionNotifierProvider);
    final clientState = ref.watch(clientConnectionStateProvider);
    final authState = ref.watch(authNotifierProvider);
    final nodeSelection = ref.watch(clientNodeSelectionProvider);
    final options = ref.watch(ConfigOptions.singboxConfigOptions);
    final activeOptions = ref.watch(connectionRepositoryProvider).configOptionsSnapshot ?? options;
    final logsState = ref.watch(logsOverviewNotifierProvider);
    final logs = logsState.logs;
    final diagnosticEvents = DiagnosticEventBuffer.recent();
    final text = _buildDiagnosticText(
      authState: authState,
      nodeSelection: nodeSelection,
      selectedNodeName: nodeSelection.valueOrNull?.selectedNode?.name,
      connection: connection,
      clientState: clientState,
      options: activeOptions,
      logs: logs,
      diagnosticEvents: diagnosticEvents,
    );

    return DesktopPageScaffold(
      title: '内部诊断',
      subtitle: '只读排查信息，复制前自动脱敏',
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.canPop() ? context.pop() : context.goNamed('settings'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('返回'),
        ),
        DesktopGradientButton(
          label: '复制诊断信息',
          icon: Icons.copy_rounded,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: DiagnosticSanitizer.sanitize(text)));
            ref.read(inAppNotificationControllerProvider).showSuccessToast('诊断信息已复制');
          },
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final summary = _SummaryPanel(
            authState: authState,
            nodeSelection: nodeSelection,
            connection: connection,
            clientState: clientState,
          );
          final config = _ConfigPanel(options: activeOptions);
          final logPanel = _LogPanel(logs: logs, diagnosticEvents: diagnosticEvents);
          if (narrow) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SizedBox(height: 360, child: summary),
                const Gap(16),
                SizedBox(height: 360, child: config),
                const Gap(16),
                SizedBox(height: 420, child: logPanel),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(child: summary),
                    const Gap(16),
                    Expanded(child: config),
                  ],
                ),
              ),
              const Gap(18),
              Expanded(flex: 6, child: logPanel),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.authState,
    required this.nodeSelection,
    required this.connection,
    required this.clientState,
  });

  final AsyncValue<AuthState> authState;
  final AsyncValue<ClientNodeSelection> nodeSelection;
  final AsyncValue<Object> connection;
  final ClientConnectionState clientState;

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      child: ListView(
        children: [
          const _SectionHeader(icon: Icons.person_search_outlined, title: '账号与连接'),
          _InfoRow(label: '登录状态', value: authState.valueOrNull?.status.name ?? 'initializing'),
          _InfoRow(label: '用户 ID', value: _diagnosticUserId(authState.valueOrNull?.session?.email)),
          _InfoRow(
            label: '节点数量',
            value: nodeSelection.when(
              data: (selection) => '${selection.nodeCount}',
              error: (_, _) => '--',
              loading: () => '读取中...',
            ),
          ),
          _InfoRow(
            label: '当前节点',
            value: DiagnosticSanitizer.sanitize(nodeSelection.valueOrNull?.selectedNode?.name ?? '--'),
          ),
          _InfoRow(label: 'VPN 权限', value: _vpnPermissionStatus(clientState)),
          _InfoRow(
            label: '核心状态',
            value: connection.when(data: _sanitizeCoreStatus, error: (_, _) => '读取失败', loading: () => '读取中...'),
          ),
          _InfoRow(label: 'ConnectionState', value: clientState.phase.name),
        ],
      ),
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({required this.options});

  final SingboxConfigOption options;

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      child: ListView(
        children: [
          const _SectionHeader(icon: Icons.fact_check_outlined, title: '核心配置摘要'),
          const _InfoRow(label: 'fakeIp', value: '${LockedCoreConfig.fakeIp}'),
          const _InfoRow(label: 'ipv6', value: '${LockedCoreConfig.ipv6}'),
          const _InfoRow(label: 'dnsStrategy', value: LockedCoreConfig.dnsStrategy),
          const _InfoRow(label: 'routeFinal', value: LockedCoreConfig.routeFinal),
          const _InfoRow(label: 'DNS mode', value: LockedCoreConfig.dnsMode),
          _InfoRow(label: 'TUN DNS server', value: DiagnosticSanitizer.sanitize(options.remoteDnsAddress)),
          const _InfoRow(label: 'outbound tag', value: LockedCoreConfig.outboundTag),
          _InfoRow(label: 'IPv6 snapshot', value: options.ipv6Mode.key),
          _InfoRow(label: 'rules', value: options.rules.isEmpty ? 'disabled' : '${options.rules.length} rule(s)'),
        ],
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.logs, required this.diagnosticEvents});

  final AsyncValue<List<LogEntity>> logs;
  final List<String> diagnosticEvents;

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: _SectionHeader(icon: Icons.description_outlined, title: '最近 100 行脱敏日志'),
          ),
          Divider(color: BrandDesktopColors.border.withOpacity(.8), height: 1),
          Expanded(
            child: logs.when(
              data: (items) {
                final coreLogLimit = (100 - diagnosticEvents.length).clamp(0, 100);
                final latest = [
                  ...diagnosticEvents,
                  ...items.take(coreLogLimit).map((log) => log.message),
                ].take(100).toList(growable: false);
                if (latest.isEmpty) return const Center(child: Text('暂无日志'));
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: latest.length,
                  separatorBuilder: (_, _) => Divider(color: BrandDesktopColors.border.withOpacity(.45), height: 14),
                  itemBuilder: (context, index) => SelectableText(
                    DiagnosticSanitizer.sanitize(latest[index]),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textSecondary, fontFamily: 'monospace'),
                  ),
                );
              },
              error: (error, _) => Center(child: Text(DiagnosticSanitizer.sanitize(error.toString()))),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DesktopIconBox(icon: icon, selected: true),
        const Gap(12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BrandDesktopColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          const Gap(12),
          Flexible(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: BrandDesktopColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

String _diagnosticUserId(String? email) => DiagnosticSanitizer.maskIdentifier(email);

String _vpnPermissionStatus(ClientConnectionState state) {
  if (state.phase == ClientConnectionPhase.requestingVpnPermission) return 'requesting';
  if (state.message == null) return 'not requested / granted';
  return state.message == '需要 VPN 权限才能加速' ? 'denied' : 'not requested / granted';
}

String _sanitizeCoreStatus(Object status) {
  final text = status is ConnectionStatus ? status.format() : status.toString();
  return DiagnosticSanitizer.sanitize(text);
}

String _buildDiagnosticText({
  required AsyncValue<AuthState> authState,
  required AsyncValue<ClientNodeSelection> nodeSelection,
  required String? selectedNodeName,
  required AsyncValue<Object> connection,
  required ClientConnectionState clientState,
  required SingboxConfigOption options,
  required AsyncValue<List<LogEntity>> logs,
  required List<String> diagnosticEvents,
}) {
  final buffer = StringBuffer()
    ..writeln('4376加速内部诊断')
    ..writeln('loginStatus=${authState.valueOrNull?.status.name ?? 'initializing'}')
    ..writeln('userId=${_diagnosticUserId(authState.valueOrNull?.session?.email)}')
    ..writeln(
      'nodeCount=${nodeSelection.when(data: (selection) => selection.nodeCount, error: (_, _) => '--', loading: () => 'loading')}',
    )
    ..writeln('selectedNodeName=${DiagnosticSanitizer.sanitize(selectedNodeName ?? '--')}')
    ..writeln('vpnPermission=${_vpnPermissionStatus(clientState)}')
    ..writeln(
      'coreStatus=${connection.when(data: _sanitizeCoreStatus, error: (_, _) => 'error', loading: () => 'loading')}',
    )
    ..writeln('connectionState=${clientState.phase.name}')
    ..writeln('fakeIp=${LockedCoreConfig.fakeIp}')
    ..writeln('ipv6=${LockedCoreConfig.ipv6}')
    ..writeln('dnsStrategy=${LockedCoreConfig.dnsStrategy}')
    ..writeln('routeFinal=${LockedCoreConfig.routeFinal}')
    ..writeln('dnsMode=${LockedCoreConfig.dnsMode}')
    ..writeln('tunDnsServer=${DiagnosticSanitizer.sanitize(options.remoteDnsAddress)}')
    ..writeln('logs:');
  for (final event in diagnosticEvents.take(100)) {
    buffer.writeln(DiagnosticSanitizer.sanitize(event));
  }
  for (final log in logs.valueOrNull?.take(100) ?? const <LogEntity>[]) {
    buffer.writeln(DiagnosticSanitizer.sanitize(log.message));
  }
  return DiagnosticSanitizer.sanitize(buffer.toString());
}
