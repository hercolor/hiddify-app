import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/config/locked_core_config.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/connection/data/windows_network_mode_guard.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/profile/data/final_config_guard.dart';
import 'package:hiddify/features/profile/data/profile_path_resolver.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/singbox/model/core_status.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:meta/meta.dart';

abstract interface class ConnectionRepository {
  SingboxConfigOption? get configOptionsSnapshot;

  TaskEither<ConnectionFailure, Unit> setup();
  Stream<ConnectionStatus> watchConnectionStatus();
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity activeProfile, bool disableMemoryLimit);
  TaskEither<ConnectionFailure, Unit> disconnect();
  TaskEither<ConnectionFailure, Unit> reconnect(ProfileEntity activeProfile, bool disableMemoryLimit);
}

class ConnectionRepositoryImpl with ExceptionHandler, InfraLogger implements ConnectionRepository {
  ConnectionRepositoryImpl({
    required this.ref,
    required this.directories,
    required this.singbox,
    required this.configOptionRepository,
    required this.profilePathResolver,
  });

  final Ref ref;

  final Directories directories;
  final HiddifyCoreService singbox;

  final ConfigOptionRepository configOptionRepository;
  final ProfilePathResolver profilePathResolver;
  final FinalConfigGuard finalConfigGuard = const FinalConfigGuard();
  final WindowsNetworkModeGuard windowsNetworkModeGuard = WindowsNetworkModeGuard();

  SingboxConfigOption? _configOptionsSnapshot;
  @override
  SingboxConfigOption? get configOptionsSnapshot => _configOptionsSnapshot;

  bool _initialized = false;

  @override
  TaskEither<ConnectionFailure, Unit> setup() {
    if (_initialized) return TaskEither.of(unit);
    return exceptionHandler(() {
      loggy.debug("setting up singbox");

      return singbox
          .setup()
          .map((r) {
            _initialized = true;
            return r;
          })
          .mapLeft(UnexpectedConnectionFailure.new)
          .run();
    }, UnexpectedConnectionFailure.new);
  }

  @override
  Stream<ConnectionStatus> watchConnectionStatus() {
    return singbox.watchStatus().map(
      (event) => switch (event) {
        CoreStopped() => Disconnected(event.getCoreAlert()),
        CoreStarting() => const Connecting(),
        CoreStarted() => const Connected(),
        CoreStopping() => const Disconnecting(),
      },
    );
  }

  @override
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity activeProfile, bool disableMemoryLimit) => setup().flatMap(
    (_) => applyConfigOption(activeProfile).flatMap(
      (_) => prepareRuntimeConfig(activeProfile, stage: 'connect').flatMap((runtimeConfigPath) {
        _logFinalConfigSummary(activeProfile);
        return singbox.start(runtimeConfigPath, activeProfile.name, disableMemoryLimit);
      }),
    ),
  );

  @override
  TaskEither<ConnectionFailure, Unit> disconnect() => singbox.stop().mapLeft(UnexpectedConnectionFailure.new);

  @override
  TaskEither<ConnectionFailure, Unit> reconnect(ProfileEntity activeProfile, bool disableMemoryLimit) =>
      applyConfigOption(activeProfile).flatMap(
        (_) => prepareRuntimeConfig(activeProfile, stage: 'reconnect').flatMap((runtimeConfigPath) {
          _logFinalConfigSummary(activeProfile);
          return singbox
              .restart(runtimeConfigPath, activeProfile.name, disableMemoryLimit)
              .mapLeft(UnexpectedConnectionFailure.new);
        }),
      );

  @visibleForTesting
  TaskEither<ConnectionFailure, Unit> applyConfigOption(ProfileEntity prof) =>
      TaskEither.fromEither(configOptionRepository.fullOptionsOverrided(prof.profileOverride))
          .mapLeft((l) => ConnectionFailure.invalidConfigOption(null, l))
          .flatMap(
            (overridedOptions) => TaskEither.tryCatch(() async {
              final modeReady = await windowsNetworkModeGuard.ensureReady(overridedOptions);
              final modeFailure = modeReady.getLeft().toNullable();
              if (modeFailure != null) throw modeFailure;
              _configOptionsSnapshot = overridedOptions;
              await singbox.changeOptions(overridedOptions).run();
              return unit;
            }, (err, st) => err is ConnectionFailure ? err : ConnectionFailure.unexpected(err, st)),
          );

  @visibleForTesting
  TaskEither<ConnectionFailure, String> prepareRuntimeConfig(ProfileEntity prof, {required String stage}) =>
      TaskEither.tryCatch(() async {
        final selection =
            ref.read(clientNodeSelectionProvider).valueOrNull ??
            await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
        final selectedOutboundTag = selection.selectedNode?.id;
        final globalRouteMode = ref.read(ConfigOptions.globalRouteMode);

        final sourceConfigPath = profilePathResolver.file(prof.id).path;
        final profileResult = await finalConfigGuard.inspectAndSanitizeFile(
          sourceConfigPath,
          stage: '$stage-profile',
          globalRouteMode: globalRouteMode,
          selectedOutboundTag: selectedOutboundTag,
        );
        _emitFinalConfigDiagnostics(
          stage: stage,
          label: 'profile',
          result: profileResult,
          globalRouteMode: globalRouteMode,
        );
        if (profileResult.hasResidualFakeIp) {
          throw const ConnectionFailure.invalidConfig(FinalConfigGuard.residualFakeIpMessage);
        }

        final generated = await singbox.generateFullConfigByPath(sourceConfigPath).run();
        final generatedContent = generated.match(
          (error) => throw ConnectionFailure.invalidConfig(error),
          (content) => content,
        );
        final runtimeResult = finalConfigGuard.inspectAndSanitizeContent(
          generatedContent,
          globalRouteMode: globalRouteMode,
          selectedOutboundTag: selectedOutboundTag,
          ensureAndroidRawInbounds: PlatformUtils.isAndroid,
        );
        final runtimeFile = profilePathResolver.file('${prof.id}.runtime');
        await runtimeFile.writeAsString(runtimeResult.sanitizedContent ?? generatedContent);
        _emitFinalConfigDiagnostics(
          stage: stage,
          label: 'runtime',
          result: runtimeResult,
          globalRouteMode: globalRouteMode,
        );
        DiagnosticEventBuffer.add(
          'runtime final config prepared: stage=$stage, parsedJson=${runtimeResult.parsedJson}, '
          'sanitized=${runtimeResult.changed}, routeRules=${runtimeResult.routeRuleCount}, '
          'inbounds=${runtimeResult.inboundSummary.length}, pathSuffix=.runtime.json',
        );
        if (runtimeResult.hasResidualFakeIp) {
          throw const ConnectionFailure.invalidConfig(FinalConfigGuard.residualFakeIpMessage);
        }
        return runtimeFile.path;
      }, (err, st) => err is ConnectionFailure ? err : ConnectionFailure.unexpected(err, st));

  @visibleForTesting
  TaskEither<ConnectionFailure, Unit> guardFinalConfig(ProfileEntity prof, {required String stage}) =>
      prepareRuntimeConfig(prof, stage: stage).map((_) => unit);

  void _emitFinalConfigDiagnostics({
    required String stage,
    required String label,
    required FinalConfigGuardResult result,
    required bool globalRouteMode,
  }) {
    DiagnosticEventBuffer.add(
      'final config check: stage=$stage, label=$label, globalRouteMode=$globalRouteMode, '
      'parsedJson=${result.parsedJson}, sanitized=${result.changed}, '
      'routeFinal=${result.routeFinal}, routeRules=${result.routeRuleCount}, '
      'dnsServers=${result.dnsServerCount}, removedClashModeRules=${result.removedClashModeRules}, '
      'removedGlobalModeRules=${result.removedGlobalModeRules}, '
      'forcedSelectedOutboundReferences=${result.forcedSelectedOutboundReferences}, '
      'removedUnselectedOutbounds=${result.removedUnselectedOutbounds}, '
      'forcedCoreLogLevel=${result.forcedCoreLogLevel}, coreLogLevel=${result.coreLogLevel}, '
      'fakeIpAfter=${result.fakeIpAfter}',
    );
    DiagnosticEventBuffer.add('final config route rules [$label]: ${result.routeRuleSummary.join(' ; ')}');
    DiagnosticEventBuffer.add('final config dns servers [$label]: ${result.dnsServerSummary.join(' ; ')}');
    DiagnosticEventBuffer.add('final config dns rules [$label]: ${result.dnsRuleSummary.join(' ; ')}');
    DiagnosticEventBuffer.add('final config rule sets [$label]: ${result.routeRuleSetSummary.join(' ; ')}');
    DiagnosticEventBuffer.add('final config inbounds [$label]: ${result.inboundSummary.join(' ; ')}');
    DiagnosticEventBuffer.add('final config outbounds [$label]: ${result.outboundTags.join(' | ')}');
  }

  void _logFinalConfigSummary(ProfileEntity profile) {
    final selectedNode = ref.read(clientNodeSelectionProvider).valueOrNull?.selectedNode;
    final nodeName = (selectedNode?.name ?? '--').replaceAll(RegExp(r'https?://[^\s]+'), 'https://***');
    loggy.debug(
      'final generated core config summary: '
      'fakeIp=${LockedCoreConfig.fakeIp}, '
      'ipv6=${LockedCoreConfig.ipv6}, '
      'dnsStrategy=${LockedCoreConfig.dnsStrategy}, '
      'routeFinal=${LockedCoreConfig.routeFinal}, '
      'selectedNodeName=$nodeName, '
      'coreConfigVersion=${LockedCoreConfig.schemaVersion}',
    );
  }
}
