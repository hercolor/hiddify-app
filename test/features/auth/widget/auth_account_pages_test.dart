import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/auth/widget/auth_account_pages.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  Future<void> pumpAuthPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 910);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: page)));
    await tester.pump();
  }

  testWidgets('registration page provides a Material surface', (tester) async {
    await pumpAuthPage(tester, const AuthRegisterPage());

    expect(tester.takeException(), isNull);
    expect(find.text('注册并登录'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('forgot-password page provides a Material surface', (tester) async {
    await pumpAuthPage(tester, const AuthForgotPasswordPage());

    expect(tester.takeException(), isNull);
    expect(find.text('重置密码'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
  });
}
