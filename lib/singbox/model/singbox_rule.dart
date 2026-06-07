import 'package:freezed_annotation/freezed_annotation.dart';

part 'singbox_rule.freezed.dart';
part 'singbox_rule.g.dart';

@freezed
class SingboxRule with _$SingboxRule {
  const SingboxRule._();

  @JsonSerializable(fieldRename: FieldRename.kebab)
  const factory SingboxRule({
    String? ruleSetUrl,
    @JsonKey(fromJson: _commaTextFromJson, toJson: _commaTextToJsonList) String? domains,
    @JsonKey(fromJson: _commaTextFromJson, toJson: _commaTextToJsonList) String? ip,
    @JsonKey(fromJson: _commaTextFromJson, toJson: _commaTextToJsonList) String? port,
    @JsonKey(fromJson: _commaTextFromJson, toJson: _commaTextToJsonList) String? protocol,
    @JsonKey(fromJson: _networkFromJson, toJson: _networkToJson) @Default(RuleNetwork.tcpAndUdp) RuleNetwork network,
    @JsonKey(fromJson: _outboundFromJson, toJson: _outboundToJson) @Default(RuleOutbound.proxy) RuleOutbound outbound,
  }) = _SingboxRule;

  factory SingboxRule.fromJson(Map<String, dynamic> json) => _$SingboxRuleFromJson(json);
}

String? _commaTextFromJson(Object? value) {
  if (value == null) return null;
  if (value is Iterable) {
    return value.map((item) => item?.toString().trim() ?? '').where((item) => item.isNotEmpty).join(',');
  }
  return value.toString();
}

Object? _commaTextToJsonList(String? value) {
  if (value == null) return null;
  final items = value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false);
  return items.isEmpty ? null : items;
}

RuleNetwork _networkFromJson(Object? value) {
  if (value is num) {
    return RuleNetwork.values.firstWhere((item) => item.value == value.toInt(), orElse: () => RuleNetwork.tcpAndUdp);
  }
  final text = value?.toString().trim().toLowerCase();
  return RuleNetwork.values.firstWhere((item) => item.key == text, orElse: () => RuleNetwork.tcpAndUdp);
}

int _networkToJson(RuleNetwork value) => value.value;

RuleOutbound _outboundFromJson(Object? value) {
  if (value is num) {
    return RuleOutbound.values.firstWhere((item) => item.value == value.toInt(), orElse: () => RuleOutbound.proxy);
  }
  final text = value?.toString().trim().toLowerCase();
  return RuleOutbound.values.firstWhere((item) => item.key == text, orElse: () => RuleOutbound.proxy);
}

int _outboundToJson(RuleOutbound value) => value.value;

enum RuleOutbound {
  proxy("proxy", 0),
  bypass("bypass", 1),
  block("block", 3);

  const RuleOutbound(this.key, this.value);

  final String key;
  final int value;
}

@JsonEnum(valueField: 'key')
enum RuleNetwork {
  tcpAndUdp("all", 0),
  tcp("tcp", 1),
  udp("udp", 2);

  const RuleNetwork(this.key, this.value);

  final String key;
  final int value;
}
