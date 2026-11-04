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
    final names = RegExp(
      r"^  ([a-z0-9_]+):",
      multiLine: true,
    ).allMatches(dependencies).map((match) => match.group(1)!).toList();

    // Guards against the parsing above silently finding nothing to check.
    expect(names, contains("sqflite"));
    expect(names.where(_isBanned), isEmpty);
  });

  test("the banned package check matches anywhere in a name", () {
    for (final name in [
      "http",
      "cupertino_http",
      "dio",
      "firebase_core",
      "sentry_flutter",
      "flutter_inappwebview",
      "google_mobile_ads",
      "easy_ads_flutter",
      "flutter_admob",
      "applovin_max",
    ]) {
      expect(_isBanned(name), isTrue, reason: name);
    }
    for (final name in ["uploads", "audio_session", "sqflite", "share_plus"]) {
      expect(_isBanned(name), isFalse, reason: name);
    }
  });
}

// Short enough to appear inside unrelated names, like "uploads" or "audio", so
// these only match a whole word of the package name.
const _bannedWords = {"ad", "ads", "dio"};

const _bannedFragments = {
  "admob",
  "analytics",
  "applovin",
  "appodeal",
  "crashlytics",
  "firebase",
  "http",
  "ironsource",
  "mixpanel",
  "sentry",
  "webview",
};

bool _isBanned(String name) =>
    name.split("_").any(_bannedWords.contains) ||
    _bannedFragments.any(name.contains);
