class AppConfig {
  const AppConfig({required this.xboardApiBaseUrl});

  final String xboardApiBaseUrl;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final baseUrl = json['xboardApiBaseUrl']?.toString().trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const FormatException('Missing xboardApiBaseUrl in app config');
    }
    return AppConfig(xboardApiBaseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''));
  }
}
