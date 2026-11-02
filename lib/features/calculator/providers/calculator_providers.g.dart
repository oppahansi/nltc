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

/// A class's glyphs in the current language.

@ProviderFor(classGlyphs)
final classGlyphsProvider = ClassGlyphsFamily._();

/// A class's glyphs in the current language.

final class ClassGlyphsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Glyph>>,
          List<Glyph>,
          FutureOr<List<Glyph>>
        >
    with $FutureModifier<List<Glyph>>, $FutureProvider<List<Glyph>> {
  /// A class's glyphs in the current language.
  ClassGlyphsProvider._({
    required ClassGlyphsFamily super.from,
    required ({int expansionId, int classId}) super.argument,
  }) : super(
         retry: null,
         name: r'classGlyphsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$classGlyphsHash();

  @override
  String toString() {
    return r'classGlyphsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Glyph>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Glyph>> create(Ref ref) {
    final argument = this.argument as ({int expansionId, int classId});
    return classGlyphs(
      ref,
      expansionId: argument.expansionId,
      classId: argument.classId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ClassGlyphsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$classGlyphsHash() => r'caec009a0216882335a3826ec6870e3a1abe887d';

/// A class's glyphs in the current language.

final class ClassGlyphsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Glyph>>,
          ({int expansionId, int classId})
        > {
  ClassGlyphsFamily._()
    : super(
        retry: null,
        name: r'classGlyphsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// A class's glyphs in the current language.

  ClassGlyphsProvider call({required int expansionId, required int classId}) =>
      ClassGlyphsProvider._(
        argument: (expansionId: expansionId, classId: classId),
        from: this,
      );

  @override
  String toString() => r'classGlyphsProvider';
}
