// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calculator_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TreeIndex)
final treeIndexProvider = TreeIndexProvider._();

final class TreeIndexProvider extends $NotifierProvider<TreeIndex, int> {
  TreeIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'treeIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$treeIndexHash();

  @$internal
  @override
  TreeIndex create() => TreeIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$treeIndexHash() => r'23d5519d1f355d836f92d03ae4a05d1733d60a3f';

abstract class _$TreeIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(savedBuilds)
final savedBuildsProvider = SavedBuildsFamily._();

final class SavedBuildsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClassBuild>>,
          List<ClassBuild>,
          FutureOr<List<ClassBuild>>
        >
    with $FutureModifier<List<ClassBuild>>, $FutureProvider<List<ClassBuild>> {
  SavedBuildsProvider._({
    required SavedBuildsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'savedBuildsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$savedBuildsHash();

  @override
  String toString() {
    return r'savedBuildsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ClassBuild>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClassBuild>> create(Ref ref) {
    final argument = this.argument as int;
    return savedBuilds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedBuildsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$savedBuildsHash() => r'86f1ab4a6a8a9ce94c6c43b84ce3302e9238219c';

final class SavedBuildsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ClassBuild>>, int> {
  SavedBuildsFamily._()
    : super(
        retry: null,
        name: r'savedBuildsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SavedBuildsProvider call(int limit) =>
      SavedBuildsProvider._(argument: limit, from: this);

  @override
  String toString() => r'savedBuildsProvider';
}
