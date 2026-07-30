import 'package:app_links/app_links.dart';
import 'package:hiddify/core/router/deep_linking/url_protocol/api.dart';
import 'package:hiddify/features/payment/model/payment_models.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_app_links.g.dart';

@riverpod
Stream<String> myAppLinks(Ref ref) async* {
  if (PlatformUtils.isWindows) {
    // 只注册自有 scheme，不再把上游导入协议写进用户注册表。
    // 运行时写 HKCU，便携版同样生效——覆盖规范 §6.3 的便携包协议注册降级项。
    registerProtocolHandler(BflyDeepLink.scheme);
  }
  yield* AppLinks().uriLinkStream.map((event) => event.toString());
}
