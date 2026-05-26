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
    @Default(RuleNetwork.tcpAndUdp) RuleNetwork network,
    @Default(RuleOutbound.proxy) RuleOutbound outbound,
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

enum RuleOutbound { proxy, bypass, block }

@JsonEnum(valueField: 'key')
enum RuleNetwork {
  tcpAndUdp(""),
  tcp("tcp"),
  udp("udp");

  const RuleNetwork(this.key);

  final String? key;
}
