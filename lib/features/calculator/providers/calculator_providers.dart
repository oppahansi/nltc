// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

part "calculator_providers.g.dart";

@Riverpod(keepAlive: true)
class TreeIndex extends _$TreeIndex {
  @override
  int build() => 0;
  void setTreeIndex(int value) => state = value;
}
