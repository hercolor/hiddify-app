Uri? customerServiceUri(String? customerService) {
  final trimmed = customerService?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme.isEmpty) {
    return _looksLikeEmail(trimmed) ? Uri(scheme: 'mailto', path: trimmed) : null;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return uri.host.trim().isEmpty ? null : uri;
  }
  if (scheme == 'tg') return uri;
  if (scheme == 'mailto') return uri.path.trim().isEmpty ? null : uri;
  return null;
}

bool _looksLikeEmail(String value) {
  if (value.contains('://') || value.contains(' ')) return false;
  final parts = value.split('@');
  return parts.length == 2 && parts[0].isNotEmpty && parts[1].contains('.');
}
