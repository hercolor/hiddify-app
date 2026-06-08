import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/model/environment.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/app_update/data/github_release_parser.dart';
import 'package:hiddify/features/app_update/model/app_update_failure.dart';
import 'package:hiddify/features/app_update/model/remote_version_entity.dart';
import 'package:hiddify/utils/utils.dart';

abstract interface class AppUpdateRepository {
  TaskEither<AppUpdateFailure, RemoteVersionEntity> getLatestVersion({
    bool includePreReleases = false,
    Release release = Release.general,
  });
}

class AppUpdateRepositoryImpl with ExceptionHandler, InfraLogger implements AppUpdateRepository {
  AppUpdateRepositoryImpl({required this.httpClient});

  final DioHttpClient httpClient;

  @override
  TaskEither<AppUpdateFailure, RemoteVersionEntity> getLatestVersion({
    bool includePreReleases = false,
    Release release = Release.general,
  }) {
    return exceptionHandler(() async {
      if (!release.allowCustomUpdateChecker) {
        throw Exception("custom update checkers are not supported");
      }

      final backendVersion = await _getLatestFromBackendVersionEndpoint();
      if (backendVersion != null) {
        return right(backendVersion);
      }

      final releaseVersion = await _getLatestFromGithubCompatibleEndpoint(includePreReleases: includePreReleases);
      if (releaseVersion != null) {
        return right(releaseVersion);
      }

      loggy.warning("failed to fetch latest version info");
      return left(const AppUpdateFailure.unexpected());
    }, AppUpdateFailure.unexpected);
  }

  Future<RemoteVersionEntity?> _getLatestFromBackendVersionEndpoint() async {
    try {
      final url = Uri.parse(
        Constants.clientVersionUrl,
      ).replace(queryParameters: {'platform': _currentPlatform()}).toString();
      final response = await httpClient.get<Map<String, dynamic>>(url);
      if (response.statusCode != 200 || response.data == null) return null;

      final envelope = response.data!;
      final data = _asMap(envelope['data']);
      final latest = _asMap(data['latest']);
      if (latest.isEmpty) return null;

      return _parseBackendVersion(latest);
    } catch (error, stackTrace) {
      loggy.warning("failed to fetch backend app version", error, stackTrace);
      return null;
    }
  }

  Future<RemoteVersionEntity?> _getLatestFromGithubCompatibleEndpoint({required bool includePreReleases}) async {
    try {
      final response = await httpClient.get<List>(Constants.githubReleasesApiUrl);
      if (response.statusCode != 200 || response.data == null) return null;

      final releases = response.data!.map((e) => GithubReleaseParser.parse(Map<String, dynamic>.from(e as Map)));
      if (includePreReleases) {
        return releases.firstOrNull;
      }
      return releases.where((e) => e.preRelease == false).firstOrNull;
    } catch (error, stackTrace) {
      loggy.warning("failed to fetch github-compatible app version", error, stackTrace);
      return null;
    }
  }

  RemoteVersionEntity _parseBackendVersion(Map<String, dynamic> json) {
    final rawVersion = _stringValue(json['version'], fallback: '0.0.0');
    final version = rawVersion.split('+').first.trim().ifEmpty('0.0.0');
    final buildNumber = _stringValue(json['build_number']);
    final releaseTag = _stringValue(json['release_tag'], fallback: 'v$rawVersion');
    final downloadUrl = _stringValue(json['download_url'], fallback: Constants.githubLatestReleaseUrl);
    final publishedAt = _dateTimeValue(json['published_at']);

    return RemoteVersionEntity(
      version: version,
      buildNumber: buildNumber,
      releaseTag: releaseTag,
      preRelease: false,
      url: downloadUrl,
      publishedAt: publishedAt,
      flavor: Environment.prod,
    );
  }

  String _currentPlatform() {
    if (PlatformUtils.isWindows) return 'windows';
    if (PlatformUtils.isMacOS) return 'macos';
    if (PlatformUtils.isAndroid) return 'android';
    if (PlatformUtils.isIOS) return 'ios';
    if (PlatformUtils.isLinux) return 'linux';
    return 'web';
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final string = value.toString().trim();
    return string.isEmpty ? fallback : string;
  }

  DateTime _dateTimeValue(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000, isUtc: true);
    if (value is String && value.trim().isNotEmpty) {
      final numeric = int.tryParse(value.trim());
      if (numeric != null) return DateTime.fromMillisecondsSinceEpoch(numeric * 1000, isUtc: true);
      return DateTime.tryParse(value.trim()) ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

extension _StringIfEmptyExtension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
