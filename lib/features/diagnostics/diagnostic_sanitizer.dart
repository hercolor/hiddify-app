abstract final class DiagnosticSanitizer {
  static String sanitize(String input) {
    var output = input;
    output = output.replaceAllMapped(_shareLinkPattern, (match) => '${match.group(1)}://***');
    output = output.replaceAllMapped(_urlPattern, (match) {
      final scheme = match.group(0)?.startsWith('http://') == true ? 'http' : 'https';
      return '$scheme://***';
    });
    output = output.replaceAllMapped(_bearerPattern, (match) => '${match.group(1)}***');
    output = output.replaceAllMapped(_sensitiveKeyValuePattern, (match) => '${match.group(1)}=***');
    output = output.replaceAllMapped(_emailPattern, (match) => '${match.group(1)}***@***');
    output = output.replaceAllMapped(_ipv4Pattern, (match) {
      final parts = match.group(0)!.split('.');
      if (parts.length != 4) return '***';
      return '${parts[0]}.${parts[1]}.*.*';
    });
    output = output.replaceAll(_ipv6Pattern, '****:****');
    output = output.replaceAllMapped(_hostPattern, (match) => '***${match.group(1) ?? ''}');
    output = output.replaceAll(_longSecretPattern, '***');
    return output;
  }

  static String maskIdentifier(String? value) {
    final input = value?.trim();
    if (input == null || input.isEmpty) return '--';
    final sanitized = sanitize(input);
    if (sanitized != input) return sanitized;
    if (input.length <= 4) return '***';
    if (input.length <= 8) return '${input.substring(0, 2)}***';
    return '${input.substring(0, 4)}***${input.substring(input.length - 2)}';
  }

  static final _shareLinkPattern = RegExp(
    r'\b(vless|vmess|trojan|ss|ssr|hysteria|hysteria2|tuic|socks|socks5)://[^\s\])}>"'
    ']+',
    caseSensitive: false,
  );
  static final _urlPattern = RegExp(
    r'\bhttps?://[^\s\])}>"'
    ']+',
    caseSensitive: false,
  );
  static final _bearerPattern = RegExp(r'\b(Bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false);
  static final _sensitiveKeyValuePattern = RegExp(
    r'''\b(authorization|auth[_-]?data|token|subscribe[_-]?token|password|passwd|pwd|server|address|host|sni|uuid|cipher)\b\s*[:=]\s*["']?([^,\s"'}\]]+)''',
    caseSensitive: false,
  );
  static final _emailPattern = RegExp(r'\b([A-Za-z0-9._%+-])[A-Za-z0-9._%+-]*@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
  static final _ipv4Pattern = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
  static final _ipv6Pattern = RegExp(r'\b(?:[0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F:.%]*\b');
  static final _hostPattern = RegExp(r'\b(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(:\d{2,5})?\b');
  static final _longSecretPattern = RegExp(r'\b[A-Za-z0-9_-]{32,}\b');
}
