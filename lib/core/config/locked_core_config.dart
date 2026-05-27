abstract final class LockedCoreConfig {
  static const int schemaVersion = 5;
  static const String schemaVersionKey = 'configSchemaVersion';

  static const String dnsMode = 'real-ip';
  static const String dnsStrategy = 'ipv4_only';
  static const String routeFinal = 'proxy';
  static const String coreLogLevel = 'debug';
  static const String outboundTag = 'proxy';
  static const String rulesBaseUrl = 'https://api.y88.pro';

  static const bool fakeIp = false;
  static const bool ipv6 = false;
  static const bool resolveDestination = true;

  static const String remoteDnsAddress = 'tcp://8.8.8.8';
  static const String directDnsAddress = 'https://223.5.5.5/dns-query';

  static const int mixedPort = 12334;
  static const int tproxyPort = 12335;
  static const int directPort = 12337;
  static const int redirectPort = 12336;
  static const int clashApiPort = 16756;
  static const int mtu = 9000;
}
