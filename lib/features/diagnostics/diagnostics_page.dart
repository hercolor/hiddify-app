import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';
import 'package:hiddify/features/log/model/log_entity.dart';
import 'package:hiddify/features/log/overview/logs_overview_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostics_page.g.dart';

class DiagnosticsPage extends HookConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionNotifierProvider);
    final clientState = ref.watch(clientConnectionStateProvider);
    final authState = ref.watch(authNotifierProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    final profiles = ref.watch(_diagnosticProfilesProvider);
    final options = ref.watch(ConfigOptions.singboxConfigOptions);
    final activeOptions = ref.watch(connectionRepositoryProvider).configOptionsSnapshot ?? options;
    final logsState = ref.watch(logsOverviewNotifierProvider);
    final logs = logsState.logs;
    final diagnosticText = _buildDiagnosticText(
      authState: authState,
      profiles: profiles,
      activeProfileName: activeProfile.valueOrNull?.name,
      connection: connection,
      clientState: clientState,
      options: activeOptions,
      logs: logs,
    );

    return Scaffold(
      appBar: AppBar(
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
                  value: profiles.when(
                    data: (items) => '${items.length}',
                    error: (_, _) => '--',
                    loading: () => '读取中...',
                  ),
                ),
                _SummaryTile(
                  label: '当前节点名称',
                  value: DiagnosticSanitizer.sanitize(activeProfile.valueOrNull?.name ?? '--'),
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
          _LogsCard(logs: logs),
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
  const _LogsCard({required this.logs});

  final AsyncValue<List<LogEntity>> logs;

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
                if (items.isEmpty) return const Center(child: Text('暂无日志'));
                final latest = items.take(100).toList();
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: latest.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final log = latest[index];
                    return Text(
                      DiagnosticSanitizer.sanitize(log.message),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
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

@Riverpod(keepAlive: true)
Future<List<ProfileEntity>> _diagnosticProfiles(Ref ref) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  final result = await repo.watchAll().first.timeout(const Duration(seconds: 2));
  return result.match((_) => const <ProfileEntity>[], (profiles) => profiles);
}

String _diagnosticUserId(String? email) => DiagnosticSanitizer.maskIdentifier(email);

String _vpnPermissionStatus(ClientConnectionState state) {
  if (state.phase == ClientConnectionPhase.requestingVpnPermission) return 'requesting';
  if (state.message == null) return 'not requested / granted';
  return state.message == '需要 VPN 权限才能加速' ? 'denied' : 'not requested / granted';
}

String _sanitizeCoreStatus(Object status) => DiagnosticSanitizer.sanitize(status.toString());

String _buildDiagnosticText({
  required AsyncValue<AuthState> authState,
  required AsyncValue<List<ProfileEntity>> profiles,
  required String? activeProfileName,
  required AsyncValue<Object> connection,
  required ClientConnectionState clientState,
  required SingboxConfigOption options,
  required AsyncValue<List<LogEntity>> logs,
}) {
  final buffer = StringBuffer()
    ..writeln('4376加速内部诊断')
    ..writeln('loginStatus=${authState.valueOrNull?.status.name ?? 'initializing'}')
    ..writeln('userId=${_diagnosticUserId(authState.valueOrNull?.session?.email)}')
    ..writeln(
      'nodeCount=${profiles.when(data: (items) => items.length, error: (_, _) => '--', loading: () => 'loading')}',
    )
    ..writeln('selectedNodeName=${DiagnosticSanitizer.sanitize(activeProfileName ?? '--')}')
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
  for (final log in logs.valueOrNull?.take(100) ?? const <LogEntity>[]) {
    buffer.writeln(DiagnosticSanitizer.sanitize(log.message));
  }
  return DiagnosticSanitizer.sanitize(buffer.toString());
}
