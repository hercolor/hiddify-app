import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LocalLegalPage(
      title: '隐私政策',
      content: '''
4376 隐私政策

本页面为本地隐私政策占位内容，正式版本将补充我们如何收集、使用、存储和保护你的账号信息、订阅信息、设备信息与连接诊断信息。

我们不会在客户端记录你的浏览内容，不会在日志中输出密码、完整登录凭证或敏感连接信息。
''',
    );
  }
}

class _LocalLegalPage extends StatelessWidget {
  const _LocalLegalPage({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [SelectableText(content, style: Theme.of(context).textTheme.bodyLarge)],
      ),
    );
  }
}
