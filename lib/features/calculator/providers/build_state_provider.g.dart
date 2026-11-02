// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'build_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BuildState)
final buildStateProvider = BuildStateProvider._();

final class BuildStateProvider
    extends $AsyncNotifierProvider<BuildState, ClassBuild> {
  BuildStateProvider._()
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

String _$buildStateHash() => r'8ae952fc83933ba249c6274d107ad0a1fed26737';

abstract class _$BuildState extends $AsyncNotifier<ClassBuild> {
  FutureOr<ClassBuild> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ClassBuild>, ClassBuild>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ClassBuild>, ClassBuild>,
              AsyncValue<ClassBuild>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
