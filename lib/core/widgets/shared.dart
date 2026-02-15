// Flutter Imports
import 'package:flutter/material.dart';

BoxDecoration getDefaultBoxDecoration(Color color) {
  return BoxDecoration(
    color: Colors.black.withAlpha(150),
    border: Border.all(color: color),
    borderRadius: BorderRadius.circular(8),
  );
}
