/// UI-only node label sanitizer for normal user surfaces.
///
/// This helper must never be used for node IDs, outbound tags, generated core
/// config, subscription parsing, or selection storage. It only protects display
/// text in Home/Nodes/tray/search UI.
String safeNodeDisplayName(String? value, {String fallback = '未命名节点'}) {
  final original = value?.trim();
  if (original == null || original.isEmpty) return fallback;

  var text = original;
  if (_looksLikeRawConfig(text)) return fallback;

  text = text
      .replaceAll(_urlPattern, ' ')
      .replaceAll(_protocolPrefixPattern, ' ')
      .replaceAll(_ipv4Pattern, ' ')
      .replaceAll(_ipv6Pattern, ' ')
      .replaceAll(_domainPattern, ' ')
      .replaceAll(_addressAssignmentPattern, ' ')
      .replaceAll(_protocolTokenPattern, ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  text = _trimDanglingSeparators(text);
  if (text.isEmpty || text == '***') return fallback;
  if (_looksLikeRawConfig(text)) return fallback;
  return text.length > 48 ? '${text.substring(0, 48)}…' : text;
}

final _urlPattern = RegExp(r'\b(?:https?|tg|mailto):\/\/\S+|\bmailto:\S+', caseSensitive: false);
final _protocolPrefixPattern = RegExp(r'\b[a-z][a-z0-9+.-]{1,16}:\/\/\S*', caseSensitive: false);
final _ipv4Pattern = RegExp(r'\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)(?::\d+)?\b');
final _ipv6Pattern = RegExp(
  r'(?<![A-Za-z0-9])(?:[0-9a-f]{0,4}:){2,}[0-9a-f]{0,4}(?:%[\w.-]+)?(?![A-Za-z0-9])',
  caseSensitive: false,
);
final _domainPattern = RegExp(
  r'\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:[a-z]{2,})(?::\d{2,5})?\b',
  caseSensitive: false,
);
final _addressAssignmentPattern = RegExp(
  r'\b(?:server|address|host|domain|port|cipher|password|uuid|alterId|sni|peer|public-key)\s*[:=]\s*\S+',
  caseSensitive: false,
);
final _protocolTokenPattern = RegExp(
  r'(?<![\p{L}\p{N}])(?:vmess|vless|trojan|shadowsocks|hysteria2?|tuic|wireguard|socks5?|http2?|grpc|ss)(?![\p{L}\p{N}])',
  caseSensitive: false,
  unicode: true,
);

bool _looksLikeRawConfig(String value) {
  if (value.length > 96) return true;
  final suspiciousSeparators = RegExp(r'[{}\[\]",]').allMatches(value).length;
  if (suspiciousSeparators >= 3) return true;
  return RegExp(
    r'\b(?:server|address|host|port|cipher|password|uuid|alterId|network|security|sni)\s*[:=]',
    caseSensitive: false,
  ).hasMatch(value);
}

String _trimDanglingSeparators(String value) {
  var text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'^[\s｜|,，:：;；/\\._\-]+'), '');
  text = text.replaceAll(RegExp(r'[\s｜|,，:：;；/\\._\-]+$'), '');
  text = text.replaceAll(RegExp(r'(?:\s*[｜|,，/\\]\s*){2,}'), ' ');
  return text.trim();
}
