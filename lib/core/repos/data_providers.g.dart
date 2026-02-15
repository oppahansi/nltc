// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(expansions)
const expansionsProvider = ExpansionsProvider._();

final class ExpansionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expansion>>,
          List<Expansion>,
          FutureOr<List<Expansion>>
        >
    with $FutureModifier<List<Expansion>>, $FutureProvider<List<Expansion>> {
  const ExpansionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expansionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expansionsHash();

  @$internal
  @override
  $FutureProviderElement<List<Expansion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Expansion>> create(Ref ref) {
    return expansions(ref);
  }
}

String _$expansionsHash() => r'8fba4c8e89f2a9b64655df576be946b3a3a2df33';

@ProviderFor(classes)
const classesProvider = ClassesProvider._();

final class ClassesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Class>>,
          List<Class>,
          FutureOr<List<Class>>
        >
    with $FutureModifier<List<Class>>, $FutureProvider<List<Class>> {
  const ClassesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classesHash();

  @$internal
  @override
  $FutureProviderElement<List<Class>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Class>> create(Ref ref) {
    return classes(ref);
  }
}

String _$classesHash() => r'71e3abdf44c3f211daa1b2fab778dc0e32cc0d67';
