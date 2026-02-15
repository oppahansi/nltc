// Flutter Imports
import "package:flutter/material.dart";

extension TextStyleFontWeightExtension on TextStyle? {
  TextStyle? withWeight(FontWeight fontWeight) =>
      this?.copyWith(fontWeight: fontWeight);
}

extension TextStyleColorExtension on TextStyle? {
  TextStyle? withColor(Color color) => this?.copyWith(color: color);
}

extension TextStyleFontSizeExtension on TextStyle? {
  TextStyle? withFontSize(double fontSize) =>
      this?.copyWith(fontSize: fontSize);
}

extension TextStyleWeightColorExtension on TextStyle? {
  TextStyle? withWeightAndColor(FontWeight fontWeight, Color color) =>
      this?.copyWith(fontWeight: fontWeight, color: color);
}

extension TextStyleFontSizeColorExtension on TextStyle? {
  TextStyle? withFontSizeAndColor(double fontSize, Color color) =>
      this?.copyWith(fontSize: fontSize, color: color);
}

extension TextStyleFontFamilyExtension on TextStyle? {
  TextStyle? withFamily(String fontFamily) =>
      this?.copyWith(fontFamily: fontFamily);
}

extension StringCapitalizeExtension on String {
  String capitalize() {
    return this[0].toUpperCase() + substring(1);
  }
}

extension BuildContextExtensions on BuildContext {
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }

  Future<T?> push<T extends Object?>(Route<T> route) {
    return Navigator.of(this).push<T>(route);
  }

  void pop<T extends Object?>([T? result]) {
    Navigator.of(this).pop(result);
  }

  void showSnackBar(SnackBar snackBar) {
    ScaffoldMessenger.of(this).showSnackBar(snackBar);
  }

  void clearSnackBars() {
    ScaffoldMessenger.of(this).clearSnackBars();
  }
}

extension ColorExtension on String {
  Color toColor() {
    var hexColor = replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    if (hexColor.length == 8) {
      return Color(int.parse("0x$hexColor"));
    }

    return Colors.black;
  }
}
