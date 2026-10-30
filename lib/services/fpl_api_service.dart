import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/fpl_models.dart';
import 'auth_service.dart';

class FplBootstrapData {
  final List<TeamClub> teams;
  final List<Player> players;
  final List<GameweekEvent> events;
  final Map<int, TeamClub> teamById;
  final Map<int, Player> playerById;

  FplBootstrapData({
    required this.teams,
    required this.players,
    required this.events,
    required this.teamById,
    required this.playerById,
  });

  GameweekEvent get currentGameweek {
    for (final e in events) {
      if (e.isCurrent) return e;
    }
    for (final e in events) {
      if (e.isNext) return e;
    }
    return events.isNotEmpty
        ? events.first
        : GameweekEvent(
            id: 1,
            name: 'Gameweek 1',
            deadlineTime: '',
            averageEntryScore: 48,
            highestScore: 117,
            isCurrent: true,
            isNext: false,
            finished: false,
            transfersMade: 0,
            chipPlaysCount: 0,
          );
  }

  GameweekEvent get nextGameweek {
    for (final e in events) {
      if (e.isNext) return e;
    }
    return currentGameweek;
  }
}

class FplApiService {
  // In-memory cache for bootstrap-static
  static FplBootstrapData? _cachedBootstrap;
  static List<FixtureItem>? _cachedFixtures;

  /// Public endpoint: bootstrap-static/ (cached in memory)
  static Future<FplBootstrapData> getBootstrapStatic(
      {bool forceRefresh = false}) async {
    if (_cachedBootstrap != null && !forceRefresh) {
      return _cachedBootstrap!;
    }

    final uri = Uri.parse('${kFplBaseUrl}bootstrap-static/');
    final resp = await http
        .get(uri, headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load bootstrap-static (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final teams = (data['teams'] as List? ?? [])
        .map((e) => TeamClub.fromJson(e as Map<String, dynamic>))
        .toList();
    final players = (data['elements'] as List? ?? [])
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();
    final events = (data['events'] as List? ?? [])
        .map((e) => GameweekEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    final teamMap = {for (final t in teams) t.id: t};
    final playerMap = {for (final p in players) p.id: p};

    _cachedBootstrap = FplBootstrapData(
      teams: teams,
      players: players,
      events: events,
      teamById: teamMap,
      playerById: playerMap,
    );
    return _cachedBootstrap!;
  }

  /// Public endpoint: fixtures/
  static Future<List<FixtureItem>> getFixtures(
      {int? eventId, bool forceRefresh = false}) async {
    if (eventId == null && _cachedFixtures != null && !forceRefresh) {
      return _cachedFixtures!;
    }
    final url = eventId != null
        ? '${kFplBaseUrl}fixtures/?event=$eventId'
        : '${kFplBaseUrl}fixtures/';
    final resp = await http
        .get(Uri.parse(url), headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load fixtures (${resp.statusCode})');
    }

    final list = (jsonDecode(resp.body) as List)
        .map((e) => FixtureItem.fromJson(e as Map<String, dynamic>))
        .toList();

    if (eventId == null) {
      _cachedFixtures = list;
    }
    return list;
  }

  /// Public endpoint: element-summary/{id}/
  static Future> getElementSummary(int playerId) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}element-summary/$playerId/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load player summary');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Public endpoint: event/{gw}/live/
  static Future>> getEventLive(int gw) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}event/$gw/live/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load live points for GW$gw');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final elements = data['elements'] as List? ?? [];
    final result = <int, Map<String, dynamic>>{};
    for (final item in elements) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as int? ?? 0;
      result[id] = map['stats'] as Map<String, dynamic>? ?? {};
    }
    return result;
  }

  /// Public endpoint: event-status/
  static Future<List>> getEventStatus() async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}event-status/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['status'] as List? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Public endpoint: entry/{id}/ (Also includes the manager's classic leagues)
  static Future> getEntry(int entryId) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}entry/$entryId/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load manager entry $entryId');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Public endpoint: entry/{id}/event/{gw}/picks/
  static Future> getEntryEventPicks(
      int entryId, int gw) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}entry/$entryId/event/$gw/picks/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load GW$gw picks for entry $entryId');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Logged-in endpoint: my-team/{id}/
  static Future> getMyTeam(int entryId) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}my-team/$entryId/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    // Fallback to current GW picks if my-team requires re-auth
    final boot = await getBootstrapStatic();
    return getEntryEventPicks(entryId, boot.currentGameweek.id);
  }

  /// Logged-in endpoint: entry/{id}/transfers-latest/ (with fallback to transfers/)
  static Future<List>> getTransfersLatest(
      int entryId) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}entry/$entryId/transfers-latest/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    final fallbackResp = await http
        .get(
          Uri.parse('${kFplBaseUrl}entry/$entryId/transfers/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (fallbackResp.statusCode == 200) {
      final decoded = jsonDecode(fallbackResp.body);
      if (decoded is List) {
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return [];
  }

  /// Public endpoint: leagues-classic/{id}/standings/
  static Future> getLeagueStandings(int leagueId) async {
    final resp = await http
        .get(
          Uri.parse('${kFplBaseUrl}leagues-classic/$leagueId/standings/'),
          headers: AuthService.getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load league $leagueId standings');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
