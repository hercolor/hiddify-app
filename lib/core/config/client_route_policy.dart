import 'package:hiddify/singbox/model/singbox_rule.dart';

abstract final class ClientRoutePolicy {
  static const cnBypassDomains = [
    'domain:.cn',
    'domain:cn',
    'domain:baidu.com',
    'domain:.baidu.com',
    'domain:qq.com',
    'domain:.qq.com',
    'domain:taobao.com',
    'domain:.taobao.com',
    'domain:tmall.com',
    'domain:.tmall.com',
    'domain:jd.com',
    'domain:.jd.com',
    'domain:alicdn.com',
    'domain:.alicdn.com',
    'domain:aliyun.com',
    'domain:.aliyun.com',
    'domain:alipay.com',
    'domain:.alipay.com',
    'domain:bilibili.com',
    'domain:.bilibili.com',
    'domain:douyin.com',
    'domain:.douyin.com',
    'domain:bytedance.com',
    'domain:.bytedance.com',
    'domain:163.com',
    'domain:.163.com',
    'domain:126.com',
    'domain:.126.com',
    'domain:sina.com.cn',
    'domain:.sina.com.cn',
    'domain:weibo.com',
    'domain:.weibo.com',
    'domain:xiaomi.com',
    'domain:.xiaomi.com',
    'domain:mi.com',
    'domain:.mi.com',
    'domain:huawei.com',
    'domain:.huawei.com',
    'domain:meituan.com',
    'domain:.meituan.com',
    'domain:amap.com',
    'domain:.amap.com',
    'domain:zhihu.com',
    'domain:.zhihu.com',
  ];

  static const cnBypassDomainSuffixes = [
    'cn',
    'qq.com',
    'weixin.qq.com',
    'wechat.com',
    'gtimg.com',
    'baidu.com',
    'bdstatic.com',
    'taobao.com',
    'tmall.com',
    'jd.com',
    '360buyimg.com',
    'alipay.com',
    'alicdn.com',
    'aliyun.com',
    'bilibili.com',
    'hdslb.com',
    'douyin.com',
    'bytedance.com',
    '163.com',
    '126.com',
    'sina.com.cn',
    'weibo.com',
    'xiaomi.com',
    'mi.com',
    'huawei.com',
    'amap.com',
    'autonavi.com',
    'meituan.com',
    'zhihu.com',
    'zhimg.com',
    'gitee.com',
    'ip138.com',
    'ip.cn',
  ];

  static const cnBypassExactDomains = ['ip138.com', 'www.ip138.com', 'ip.cn', 'www.ip.cn'];

  static const cnBypassDomainKeywords = [
    'baidu',
    'alicdn',
    'taobao',
    'tencent',
    'alipay',
    'bilibili',
    'douyin',
    'bytedance',
    'huawei',
    'xiaomi',
    'netease',
    'meituan',
    'pinduoduo',
    'jingdong',
  ];

  static const privateIpv4Cidrs = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8', '169.254.0.0/16'];

  static const smartRules = <SingboxRule>[
    SingboxRule(domains: _cnBypassDomainsText, outbound: RuleOutbound.bypass),
    SingboxRule(ip: _privateIpv4CidrsText, outbound: RuleOutbound.bypass),
  ];

  static const _cnBypassDomainsText =
      'domain:cn,'
      'domain:.cn,'
      'domain:qq.com,'
      'domain:.qq.com,'
      'domain:baidu.com,'
      'domain:.baidu.com,'
      'domain:taobao.com,'
      'domain:.taobao.com,'
      'domain:tmall.com,'
      'domain:.tmall.com,'
      'domain:jd.com,'
      'domain:.jd.com,'
      'domain:alicdn.com,'
      'domain:.alicdn.com,'
      'domain:aliyun.com,'
      'domain:.aliyun.com,'
      'domain:alipay.com,'
      'domain:.alipay.com,'
      'domain:bilibili.com,'
      'domain:.bilibili.com,'
      'domain:douyin.com,'
      'domain:.douyin.com,'
      'domain:bytedance.com,'
      'domain:.bytedance.com,'
      'domain:163.com,'
      'domain:.163.com,'
      'domain:126.com,'
      'domain:.126.com,'
      'domain:sina.com.cn,'
      'domain:.sina.com.cn,'
      'domain:weibo.com,'
      'domain:.weibo.com,'
      'domain:xiaomi.com,'
      'domain:.xiaomi.com,'
      'domain:mi.com,'
      'domain:.mi.com,'
      'domain:huawei.com,'
      'domain:.huawei.com,'
      'domain:meituan.com,'
      'domain:.meituan.com,'
      'domain:amap.com,'
      'domain:.amap.com,'
      'domain:zhihu.com,'
      'domain:.zhihu.com,'
      'domain:ip138.com,'
      'domain:.ip138.com,'
      'domain:ip.cn,'
      'domain:.ip.cn';

  static const _privateIpv4CidrsText = '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.0/8,169.254.0.0/16';

  static List<SingboxRule> rulesFor({required bool globalRouteMode}) =>
      globalRouteMode ? const <SingboxRule>[] : smartRules;

  static List<SingboxRule> lockedRules(Iterable<SingboxRule> rules) =>
      rules.where((rule) => smartRules.contains(rule)).toList(growable: false);
}
