// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'singbox_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SingboxRuleImpl _$$SingboxRuleImplFromJson(Map<String, dynamic> json) =>
    _$SingboxRuleImpl(
      ruleSetUrl: json['rule-set-url'] as String?,
      domains: _commaTextFromJson(json['domains']),
      ip: _commaTextFromJson(json['ip']),
      port: _commaTextFromJson(json['port']),
      protocol: _commaTextFromJson(json['protocol']),
      network: _networkFromJson(json['network']),
      outbound:
          $enumDecodeNullable(_$RuleOutboundEnumMap, json['outbound']) ??
          RuleOutbound.proxy,
    );

Map<String, dynamic> _$$SingboxRuleImplToJson(_$SingboxRuleImpl instance) =>
    <String, dynamic>{
      'rule-set-url': instance.ruleSetUrl,
      'domains': _commaTextToJsonList(instance.domains),
      'ip': _commaTextToJsonList(instance.ip),
      'port': _commaTextToJsonList(instance.port),
      'protocol': _commaTextToJsonList(instance.protocol),
      'network': _networkToJson(instance.network),
      'outbound': _$RuleOutboundEnumMap[instance.outbound]!,
    };

const _$RuleOutboundEnumMap = {
  RuleOutbound.proxy: 'proxy',
  RuleOutbound.bypass: 'bypass',
  RuleOutbound.block: 'block',
};
