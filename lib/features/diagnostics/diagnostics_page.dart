import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/log/model/log_entity.dart';
import 'package:hiddify/features/log/overview/logs_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DiagnosticsPage extends HookConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionNotifierProvider);
    final options = ref.watch(ConfigOptions.singboxConfigOptions);
    final activeOptions = ref.watch(connectionRepositoryProvider).configOptionsSnapshot ?? options;
    final logsState = ref.watch(logsOverviewNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('诊断')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('核心状态'),
                  subtitle: Text(
                    connection.when(
                      data: (value) => value.format(),
                      error: (error, _) => error.toString(),
                      loading: () => '读取中...',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ConfigSummaryCard(options: activeOptions),
          const SizedBox(height: 12),
          _LogsCard(logs: logsState.logs),
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
          const _SummaryTile(label: 'DNS mode', value: 'real-ip'),
          _SummaryTile(label: 'fake-ip', value: options.enableFakeDns ? 'enabled' : 'disabled'),
          _SummaryTile(label: 'TUN DNS server', value: options.remoteDnsAddress),
          const _SummaryTile(label: 'route final', value: 'proxy'),
          const _SummaryTile(label: 'outbound tag', value: 'proxy'),
          _SummaryTile(label: 'IPv6', value: options.ipv6Mode.key),
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
            title: Text('最近日志'),
            subtitle: Text('仅显示最近 80 条，并自动隐藏敏感链接和 Authorization。'),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 360,
            child: logs.when(
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('暂无日志'));
                final latest = items.take(80).toList();
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: latest.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final log = latest[index];
                    return Text(_sanitizeLogMessage(log.message), style: Theme.of(context).textTheme.bodySmall);
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

String _sanitizeLogMessage(String message) {
  return message
      .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false), 'Bearer ***')
      .replaceAll(RegExp(r'''(authorization["']?\s*[:=]\s*["']?)[^,\s"']+''', caseSensitive: false), r'$1***')
      .replaceAll(RegExp(r'https?://[^\s]+'), 'https://***');
}
