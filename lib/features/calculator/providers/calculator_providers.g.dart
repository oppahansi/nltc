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
