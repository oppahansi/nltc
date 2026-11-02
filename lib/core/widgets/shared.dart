// Flutter Imports
import 'package:flutter/material.dart';

BoxDecoration getDefaultBoxDecoration(Color color) {
  return BoxDecoration(
    color: Colors.black.withAlpha(150),
    border: Border.all(color: color),
    borderRadius: BorderRadius.circular(8),
  );
}

extension OwnMaterial on Widget {
  /// Lets tap ripples show above a decorated background, which would otherwise
  /// hide them.
  Widget get onOwnMaterial =>
      Material(type: MaterialType.transparency, child: this);
}
