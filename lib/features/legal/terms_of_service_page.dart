import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LocalLegalPage(
      title: '用户协议',
      content: '''
蝴蝶加速 用户协议

本页面为本地用户协议占位内容，正式版本将补充账号注册、套餐购买、服务使用、退款规则、可接受使用范围和责任限制等条款。

请遵守当地法律法规和平台服务规则，合理使用本客户端提供的网络连接服务。
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
