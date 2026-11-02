// Dart Imports
import "dart:io";

// Package Imports
import "package:flutter_test/flutter_test.dart";

// The Play Data safety form declares that the app collects and shares nothing.
// If one of these has to change, the form and privacy policy have to as well.
void main() {
  test("release builds can't reach the network", () {
    final manifest = File("android/app/src/main/AndroidManifest.xml")
        .readAsStringSync();
    expect(manifest, isNot(contains("android.permission.INTERNET")));
  });

  test("no networking or tracking packages are direct dependencies", () {
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final dependencies = pubspec.substring(
      pubspec.indexOf("dependencies:"),
      pubspec.indexOf("dev_dependencies:"),
    );
    for (final name in [
      "http",
      "dio",
      "firebase",
      "sentry",
      "webview",
      "ads",
    ]) {
      expect(dependencies, isNot(contains("  $name")), reason: name);
    }
  });
}
