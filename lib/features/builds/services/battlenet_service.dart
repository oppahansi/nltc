// Dart Imports
import "dart:async";
// ADDED
import "dart:convert";
import "dart:io";

// Flutter Imports
import "package:flutter/foundation.dart" show kIsWeb, kReleaseMode, debugPrint;

// Package Imports
import "package:http/http.dart" as http;

// Project Imports
import "package:ltc/features/builds/models/builds_entities.dart";

const String _envTokenHost = String.fromEnvironment(
  "LOCAL_TOKEN_HOST",
  defaultValue: "",
);
const String _envTokenPort = String.fromEnvironment(
  "LOCAL_TOKEN_PORT",
  defaultValue: "8080",
);
const String _envTokenApiKey = String.fromEnvironment(
  "LOCAL_TOKEN_API_KEY",
  defaultValue: "REDACTED",
);

// Remote (release) token host configuration (optional overrides)
const String _envRemoteTokenHost = String.fromEnvironment(
  "REMOTE_TOKEN_HOST",
  defaultValue: "",
);
const String _envRemoteTokenPort = String.fromEnvironment(
  "REMOTE_TOKEN_PORT",
  defaultValue: "8080",
);
const String _envRemoteTokenIp = String.fromEnvironment(
  "REMOTE_TOKEN_IP",
  defaultValue: "",
);

// Toggle: if local host (10.0.2.2 / override) fails, try remote automatically.
const bool _enableLocalThenRemoteFallback = true;

// Added: choose scheme (http for debug/profile, https for release)
String get _tokenScheme => kReleaseMode ? "https" : "http";

class BattleNetApiService {
  static final BattleNetApiService _instance = BattleNetApiService._internal();
  factory BattleNetApiService() => _instance;
  BattleNetApiService._internal();

  BattleNetToken? _cachedToken;

  static const _profileNamespacePrefix = "profile-classic1x-";
  static const Map<String, String> _regionDefaultLocales = {
    "us": "en_US",
    "eu": "en_GB",
    "kr": "ko_KR",
    "tw": "zh_TW",
  };

  Future<RemoteClassBuilds> fetchClassBuilds({
    required String region,
    required String server,
    required String characterName,
  }) async {
    final token = await _getToken(region);
    final namespace = "$_profileNamespacePrefix$region";
    final resolvedLocale =
        _regionDefaultLocales[region.toLowerCase()] ?? "en_US";

    final characterUri = Uri.https(
      "$region.api.blizzard.com",
      "/profile/wow/character/$server/${characterName.toLowerCase()}",
      {"namespace": namespace, "locale": resolvedLocale},
    );
    final charJson = await _getJson(characterUri, token.accessToken);

    Uri specsUri;
    final specializations = charJson["specializations"];
    if (specializations is Map<String, dynamic> &&
        specializations["href"] is String) {
      specsUri = Uri.parse(specializations["href"]);
    } else {
      specsUri = Uri.https(
        "$region.api.blizzard.com",
        "/profile/wow/character/$server/${characterName.toLowerCase()}/specializations",
        {"namespace": namespace, "locale": resolvedLocale},
      );
    }

    final specsJson = await _getJson(specsUri, token.accessToken);
    final charBuilds = <RemoteClassBuild>[];

    final specGroups = specsJson["specialization_groups"] ?? [];
    for (final sg in specGroups) {
      final Map<String, Map<String, int>> talentTrees = {};
      final isActive = sg["is_active"] == true;

      final specs = sg["specializations"] ?? [];
      for (final spec in specs) {
        final treeName = spec["specialization_name"]?["en_US"] ?? "Unknown";
        final talentRanks = <String, int>{};

        final talents = spec["talents"] ?? [];
        for (final t in talents) {
          final talentName =
              t["spell_tooltip"]?["spell"]?["name"]?["en_US"] ?? "Talent";
          final talentRank = (t["talent_rank"] ?? 0) as int;
          talentRanks[talentName] = talentRank;
        }

        talentTrees[treeName] = talentRanks;
      }

      charBuilds.add(RemoteClassBuild(isActive, talentTrees));
    }

    return RemoteClassBuilds(
      className: _extractClassName(charJson),
      builds: charBuilds,
    );
  }

  String _extractClassName(Map<String, dynamic> charJson) {
    final cc = charJson["character_class"];
    if (cc is Map) {
      final name = cc["name"];
      if (name is String && name.isNotEmpty) return name;
    }
    return "";
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String accessToken) async {
    final resp = await http.get(
      uri,
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (resp.statusCode != 200) {
      final preview = _bodyPreview(resp.body);
      throw Exception("HTTP ${resp.statusCode} ${uri.path}: $preview");
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  String _bodyPreview(String body, {int maxLen = 500}) {
    if (body.length <= maxLen) return body;
    return "${body.substring(0, maxLen)}...";
  }

  Future<BattleNetToken> _getToken(String region) async {
    if (_cachedToken != null && !_cachedToken!.isExpired) {
      return _cachedToken!;
    }

    // Allow 30s grace after expiry if call fails (prevents UI thrash)
    final graceSeconds = 30;
    final now = DateTime.now();
    if (_cachedToken != null &&
        now.difference(_cachedToken!.expiry).inSeconds <= graceSeconds) {
      try {
        return await _fetchToken(); // attempt refresh
      } catch (_) {
        return _cachedToken!; // fallback to slightly expired
      }
    }

    try {
      return await _fetchToken();
    } catch (e) {
      throw Exception("Failed to obtain Battle.net token: $e");
    }
  }

  Future<BattleNetToken> _fetchToken() async {
    final bool hasLocalOverride = _envTokenHost.isNotEmpty;
    final bool useRemotePrimary = !hasLocalOverride && kReleaseMode;

    final primaryHost = useRemotePrimary
        ? _determineRemoteHost()
        : _determineLocalHost();
    final primaryPort = useRemotePrimary
        ? _determineRemotePort()
        : (_envTokenPort.isEmpty ? "8080" : _envTokenPort);

    // Changed: build URI with dynamic scheme
    final uriPrimary = _buildTokenUri(
      host: primaryHost,
      port: primaryPort,
      scheme: _tokenScheme,
    );

    debugPrint(
      "TOKEN_FETCH primary uri=$uriPrimary mode=${kReleaseMode ? "release" : "debug"} "
      "hasLocalOverride=$hasLocalOverride useRemotePrimary=$useRemotePrimary",
    );

    try {
      return await _fetchTokenFromUri(uriPrimary);
    } on Exception catch (e) {
      final msg = e.toString();
      final isLocalAttempt = !useRemotePrimary;
      final maybeConnRefused =
          msg.contains("SocketException") ||
          msg.contains("Connection refused") ||
          msg.contains("timed out");

      if (_enableLocalThenRemoteFallback &&
          isLocalAttempt &&
          maybeConnRefused) {
        final fallbackHost = _determineRemoteHost();
        final fallbackPort = _determineRemotePort();
        final uriFallback = _buildTokenUri(
          host: fallbackHost,
          port: fallbackPort,
          scheme: "https", // still respects build mode
        );
        debugPrint(
          "TOKEN_FETCH fallback -> remote uri=$uriFallback (reason: $msg)",
        );
        try {
          return await _fetchTokenFromUri(uriFallback);
        } catch (e2) {
          throw Exception(
            "Token fetch failed (local + remote). Local error: $msg | Remote error: $e2",
          );
        }
      }
      rethrow;
    }
  }

  Future<BattleNetToken> _fetchTokenFromUri(Uri uri) async {
    http.Response resp;
    try {
      resp = await http.get(uri).timeout(const Duration(seconds: 6));
    } on SocketException catch (e) {
      final host = uri.host;
      debugPrint("SocketException contacting $uri : ${e.message}");

      // Try IP fallback (only if configured and host matches remote host)
      if (_envRemoteTokenIp.isNotEmpty && host == _determineRemoteHost()) {
        final ipUri = uri.replace(host: _envRemoteTokenIp);
        debugPrint("TOKEN_FETCH retry via IP $ipUri");
        try {
          resp = await http.get(ipUri).timeout(const Duration(seconds: 6));
        } on Exception catch (e2) {
          // DNS diagnostics before failing
          try {
            final addrs = await InternetAddress.lookup(host);
            debugPrint("DNS $host -> $addrs");
          } catch (dnsE) {
            debugPrint("DNS lookup failed for $host: $dnsE");
          }
          throw Exception("IP fallback failed ($ipUri): $e2");
        }
      } else {
        // DNS diagnostics (only if no IP fallback succeeded)
        try {
          final addrs = await InternetAddress.lookup(host);
          debugPrint("DNS $host -> $addrs");
        } catch (dnsE) {
          debugPrint("DNS lookup failed for $host: $dnsE");
        }
        throw Exception(
          "SocketException contacting $uri : ${e.message} (host=$host)",
        );
      }
    } on TimeoutException {
      throw Exception("Timeout (6s) contacting $uri");
    } catch (e) {
      throw Exception("General error contacting $uri : $e");
    }

    if (resp.statusCode != 200) {
      throw Exception(
        "HTTP ${resp.statusCode} from $uri body=${_bodyPreview(resp.body)}",
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Invalid JSON from $uri body=${_bodyPreview(resp.body)}");
    }

    final accessToken = data["access_token"];
    if (accessToken is! String || accessToken.isEmpty) {
      throw Exception("Missing access_token from $uri body=${resp.body}");
    }

    const assumedExpiresInSeconds = 3600;
    final token = BattleNetToken(
      accessToken: accessToken,
      expiresIn: assumedExpiresInSeconds,
      obtainedAt: DateTime.now(),
    );
    _cachedToken = token;
    return token;
  }

  // Added helper to safely build token URI
  Uri _buildTokenUri({
    required String host,
    required String port,
    required String scheme,
  }) {
    final parsedPort = int.tryParse(port) ?? 8080;
    return Uri(
      scheme: scheme,
      host: host,
      port: parsedPort,
      path: "/get-token",
      queryParameters: {"api_key": _envTokenApiKey},
    );
  }

  String _determineLocalHost() {
    if (_envTokenHost.isNotEmpty) return _envTokenHost;
    if (kIsWeb) return "localhost";
    try {
      if (Platform.isAndroid) return "10.0.2.2";
      return "localhost";
    } catch (_) {
      return "localhost";
    }
  }

  String _determineRemoteHost() {
    if (_envRemoteTokenHost.isNotEmpty) return _envRemoteTokenHost;
    return "ltc.oppahansi.de";
  }

  String _determineRemotePort() {
    if (_envRemoteTokenPort.isNotEmpty) return _envRemoteTokenPort;
    return "8080";
  }

  Future<List<Realm>> fetchRealms({required String region}) async {
    final token = await _getToken(region);
    final namespace = "dynamic-classic1x-$region";
    final locale = _regionDefaultLocales[region.toLowerCase()] ?? "en_US";

    final uri = Uri.https("$region.api.blizzard.com", "/data/wow/realm/index", {
      "namespace": namespace,
      "locale": locale,
    });

    final json = await _getJson(uri, token.accessToken);
    final realmsJson = json["realms"];
    if (realmsJson is! List) return const [];

    return realmsJson
        .whereType<Map>()
        .map(
          (r) => Realm(
            id: (r["id"] as num).toInt(),
            name: (r["name"] ?? "").toString(),
            slug: (r["slug"] ?? "").toString(),
          ),
        )
        .where((r) => r.slug.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
