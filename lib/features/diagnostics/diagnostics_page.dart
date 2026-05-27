import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/diagnostics/core_log_file_snapshot.dart';
import 'package:hiddify/features/diagnostics/desktop_diagnostics_page.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';
import 'package:hiddify/features/log/data/log_data_providers.dart';
import 'package:hiddify/features/log/model/log_entity.dart';
import 'package:hiddify/features/log/overview/logs_overview_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DiagnosticsPage extends HookConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isWindows) return const DesktopDiagnosticsPage();

    final connection = ref.watch(connectionNotifierProvider);
    final clientState = ref.watch(clientConnectionStateProvider);
    final authState = ref.watch(authNotifierProvider);
    final nodeSelection = ref.watch(clientNodeSelectionProvider);
    final options = ref.watch(ConfigOptions.singboxConfigOptions);
    final activeOptions = ref.watch(connectionRepositoryProvider).configOptionsSnapshot ?? options;
    final logsState = ref.watch(logsOverviewNotifierProvider);
    final logs = logsState.logs;
    final diagnosticEvents = DiagnosticEventBuffer.recent();
    final coreLogFileLines = CoreLogFileSnapshot.readTail(ref.watch(logPathResolverProvider).coreFile());
    final diagnosticText = _buildDiagnosticText(
      authState: authState,
      nodeSelection: nodeSelection,
      selectedNodeName: nodeSelection.valueOrNull?.selectedNode?.name,
      connection: connection,
      clientState: clientState,
      options: activeOptions,
      logs: logs,
      diagnosticEvents: diagnosticEvents,
      coreLogFileLines: coreLogFileLines,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('settings');
            }
          },
        ),
        title: const Text('内部诊断'),
        actions: [
          IconButton(
            tooltip: '复制诊断信息',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: DiagnosticSanitizer.sanitize(diagnosticText)));
              ref.read(inAppNotificationControllerProvider).showSuccessToast('诊断信息已复制');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('只读内部诊断'),
              subtitle: Text('本页面不可修改配置；信息会自动脱敏，不包含完整 token、订阅链接、节点密码或完整服务器地址。'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(leading: Icon(Icons.person_search_outlined), title: Text('账号与连接')),
                const Divider(height: 1),
                _SummaryTile(label: '登录状态', value: authState.valueOrNull?.status.name ?? 'initializing'),
                _SummaryTile(label: '用户 ID', value: _diagnosticUserId(authState.valueOrNull?.session?.email)),
                _SummaryTile(
                  label: '节点数量',
                  value: nodeSelection.when(
                    data: (selection) => '${selection.nodeCount}',
                    error: (_, _) => '--',
                    loading: () => '读取中...',
                  ),
                ),
                _SummaryTile(
                  label: '当前节点名称',
                  value: DiagnosticSanitizer.sanitize(nodeSelection.valueOrNull?.selectedNode?.name ?? '--'),
                ),
                _SummaryTile(label: 'VPN 权限状态', value: _vpnPermissionStatus(clientState)),
                _SummaryTile(
                  label: '核心运行状态',
                  value: connection.when(data: _sanitizeCoreStatus, error: (_, _) => '读取失败', loading: () => '读取中...'),
                ),
                _SummaryTile(label: 'ConnectionState', value: clientState.phase.name),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ConfigSummaryCard(options: activeOptions),
          const SizedBox(height: 12),
          _LogsCard(logs: logs, diagnosticEvents: diagnosticEvents, coreLogFileLines: coreLogFileLines),
        ],
      ),
    );
  }
}

class _ConfigSummaryCard extends StatelessWidget {
  const _ConfigSummaryCard({required this.options});

  final SingboxConfigOption options;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.fact_check_outlined),
            title: Text('当前生成配置摘要'),
            subtitle: Text('只读诊断信息，不包含密码、token 或订阅链接。'),
          ),
          const Divider(height: 1),
          const _SummaryTile(label: 'fakeIp', value: '${LockedCoreConfig.fakeIp}'),
          const _SummaryTile(label: 'ipv6', value: '${LockedCoreConfig.ipv6}'),
          const _SummaryTile(label: 'dnsStrategy', value: LockedCoreConfig.dnsStrategy),
          const _SummaryTile(label: 'routeFinal', value: LockedCoreConfig.routeFinal),
          const _SummaryTile(label: 'DNS mode', value: LockedCoreConfig.dnsMode),
          _SummaryTile(label: 'TUN DNS server', value: DiagnosticSanitizer.sanitize(options.remoteDnsAddress)),
          const _SummaryTile(label: 'outbound tag', value: LockedCoreConfig.outboundTag),
          _SummaryTile(label: 'IPv6 mode snapshot', value: options.ipv6Mode.key),
          _SummaryTile(label: 'rules', value: options.rules.isEmpty ? 'disabled' : '${options.rules.length} rule(s)'),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value, textDirection: TextDirection.ltr),
    );
  }
}

class _LogsCard extends StatelessWidget {
  const _LogsCard({required this.logs, required this.diagnosticEvents, required this.coreLogFileLines});

  final AsyncValue<List<LogEntity>> logs;
  final List<String> diagnosticEvents;
  final List<String> coreLogFileLines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('最近 100 行脱敏日志'),
            subtitle: Text('自动隐藏敏感链接、Authorization、token、节点密码和完整服务器地址。'),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 360,
            child: logs.when(
              data: (items) {
                final coreLogLimit = (100 - diagnosticEvents.length).clamp(0, 100);
                final latest = [
                  ...diagnosticEvents,
                  ...coreLogFileLines,
                  ...items.take(coreLogLimit).map((log) => log.message),
                ].take(100).toList(growable: false);
                if (latest.isEmpty) return const Center(child: Text('暂无日志'));
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: latest.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final log = latest[index];
                    return Text(DiagnosticSanitizer.sanitize(log), style: Theme.of(context).textTheme.bodySmall);
                  },
                );
              },
              error: (error, _) => Center(child: Text(error.toString())),
              loading: () => const Center(child: CircularProgressIndicator()),
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
  required List<String> coreLogFileLines,
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
    ..writeln('resolveDestination=${LockedCoreConfig.resolveDestination}')
    ..writeln('dnsStrategy=${LockedCoreConfig.dnsStrategy}')
    ..writeln('routeFinal=${LockedCoreConfig.routeFinal}')
    ..writeln('dnsMode=${LockedCoreConfig.dnsMode}')
    ..writeln('tunDnsServer=${DiagnosticSanitizer.sanitize(options.remoteDnsAddress)}')
    ..writeln('logs:');
  for (final event in diagnosticEvents.take(120)) {
    buffer.writeln(DiagnosticSanitizer.sanitize(event));
  }
  for (final line in coreLogFileLines.take(80)) {
    buffer.writeln(DiagnosticSanitizer.sanitize(line));
  }
  for (final log in logs.valueOrNull?.take(80) ?? const <LogEntity>[]) {
    buffer.writeln(DiagnosticSanitizer.sanitize(log.message));
  }
  return DiagnosticSanitizer.sanitize(buffer.toString());
}
