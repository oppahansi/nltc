// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'builds_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SelectedRegion)
const selectedRegionProvider = SelectedRegionProvider._();

final class SelectedRegionProvider
    extends $NotifierProvider<SelectedRegion, String> {
  const SelectedRegionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedRegionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedRegionHash();

  @$internal
  @override
  SelectedRegion create() => SelectedRegion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$selectedRegionHash() => r'53e08a1134b756f44bc05af04e9ac6662a5651dc';

abstract class _$SelectedRegion extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(realms)
const realmsProvider = RealmsFamily._();

final class RealmsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Realm>>,
          List<Realm>,
          FutureOr<List<Realm>>
        >
    with $FutureModifier<List<Realm>>, $FutureProvider<List<Realm>> {
  const RealmsProvider._({
    required RealmsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'realmsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$realmsHash();

  @override
  String toString() {
    return r'realmsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Realm>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Realm>> create(Ref ref) {
    final argument = this.argument as String;
    return realms(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RealmsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$realmsHash() => r'60f164e15929e03fc3694daef19fb4eb517dfd14';

final class RealmsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Realm>>, String> {
  const RealmsFamily._()
    : super(
        retry: null,
        name: r'realmsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RealmsProvider call(String region) =>
      RealmsProvider._(argument: region, from: this);

  @override
  String toString() => r'realmsProvider';
}

@ProviderFor(SelectedRealm)
const selectedRealmProvider = SelectedRealmProvider._();

final class SelectedRealmProvider
    extends $NotifierProvider<SelectedRealm, String?> {
  const SelectedRealmProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedRealmProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedRealmHash();

  @$internal
  @override
  SelectedRealm create() => SelectedRealm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedRealmHash() => r'4c8ff6fdf09ad3ff3cfafdedf175ddb62f14ccd4';

abstract class _$SelectedRealm extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(SelectedCharName)
const selectedCharNameProvider = SelectedCharNameProvider._();

final class SelectedCharNameProvider
    extends $NotifierProvider<SelectedCharName, String> {
  const SelectedCharNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedCharNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedCharNameHash();

  @$internal
  @override
  SelectedCharName create() => SelectedCharName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$selectedCharNameHash() => r'282ecb6f5f1c00b205859b496370f623fb406af6';

abstract class _$SelectedCharName extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(RemoteClassBuilds)
const remoteClassBuildsProvider = RemoteClassBuildsProvider._();

final class RemoteClassBuildsProvider
    extends $NotifierProvider<RemoteClassBuilds, AsyncValue<List<ClassBuild>>> {
  const RemoteClassBuildsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteClassBuildsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteClassBuildsHash();

  @$internal
  @override
  RemoteClassBuilds create() => RemoteClassBuilds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<ClassBuild>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<ClassBuild>>>(value),
    );
  }
}

String _$remoteClassBuildsHash() => r'650e3351369186c8b2cd09b67b0ae373b7557486';

abstract class _$RemoteClassBuilds
    extends $Notifier<AsyncValue<List<ClassBuild>>> {
  AsyncValue<List<ClassBuild>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<ClassBuild>>, AsyncValue<List<ClassBuild>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ClassBuild>>,
                AsyncValue<List<ClassBuild>>
              >,
              AsyncValue<List<ClassBuild>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
