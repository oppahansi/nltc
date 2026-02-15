// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'build_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BuildState)
const buildStateProvider = BuildStateProvider._();

final class BuildStateProvider
    extends $AsyncNotifierProvider<BuildState, ClassBuild> {
  const BuildStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'buildStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$buildStateHash();

  @$internal
  @override
  BuildState create() => BuildState();
}

String _$buildStateHash() => r'7d3dcbb3b3973aa635431e4986900606f5affadb';

abstract class _$BuildState extends $AsyncNotifier<ClassBuild> {
  FutureOr<ClassBuild> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<ClassBuild>, ClassBuild>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ClassBuild>, ClassBuild>,
              AsyncValue<ClassBuild>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
