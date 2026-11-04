// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_builds_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

String _$savedBuildsHash() => r'32e6a84a5f079c0d2c97fe87ecd24fbdd03e7d7a';

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
