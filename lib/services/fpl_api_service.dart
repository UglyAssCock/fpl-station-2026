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
  static FplBootstrapData? _cachedBootstrap;
  static List<FixtureItem>? _cachedFixtures;

  static Future<FplBootstrapData> getBootstrapStatic(
      {bool forceRefresh = false}) async {
    if (_cachedBootstrap != null && !forceRefresh) return _cachedBootstrap!;
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}bootstrap-static/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Failed bootstrap (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final teams = (data['teams'] as Iterable? ?? [])
        .map((e) => TeamClub.fromJson(e as Map<String, dynamic>))
        .toList();
    final players = (data['elements'] as Iterable? ?? [])
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();
    final events = (data['events'] as Iterable? ?? [])
        .map((e) => GameweekEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    _cachedBootstrap = FplBootstrapData(
      teams: teams,
      players: players,
      events: events,
      teamById: {for (final t in teams) t.id: t},
      playerById: {for (final p in players) p.id: p},
    );
    return _cachedBootstrap!;
  }

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
      throw Exception('Failed fixtures (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Iterable;
    final list = decoded
        .map((e) => FixtureItem.fromJson(e as Map<String, dynamic>))
        .toList();
    if (eventId == null) _cachedFixtures = list;
    return list;
  }

  static Future> getElementSummary(int playerId) async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}element-summary/$playerId/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('Failed player summary');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future>> getEventLive(int gw) async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}event/$gw/live/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('Failed live GW$gw');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final elements = data['elements'] as Iterable? ?? [];
    final result = <int, Map<String, dynamic>>{};
    for (final item in elements) {
      final map = item as Map<String, dynamic>;
      result[map['id'] as int? ?? 0] =
          map['stats'] as Map<String, dynamic>? ?? {};
    }
    return result;
  }

  static Future<List>> getEventStatus() async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}event-status/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['status'] as Iterable? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  static Future> getEntry(int entryId) async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}entry/$entryId/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('Failed entry $entryId');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future> getEntryEventPicks(
      int entryId, int gw) async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}entry/$entryId/event/$gw/picks/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('Failed picks GW$gw');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future> getMyTeam(int entryId) async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}my-team/$entryId/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    final boot = await getBootstrapStatic();
    return getEntryEventPicks(entryId, boot.currentGameweek.id);
  }

  static Future<List>> getTransfersLatest(
      int entryId) async {
    for (final suffix in ['transfers-latest/', 'transfers/']) {
      final resp = await http
          .get(Uri.parse('${kFplBaseUrl}entry/$entryId/$suffix'),
              headers: AuthService.getAuthHeaders())
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Iterable) {
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        }
      }
    }
    return [];
  }

  static Future> getLeagueStandings(int leagueId) async {
    final resp = await http
        .get(Uri.parse('${kFplBaseUrl}leagues-classic/$leagueId/standings/'),
            headers: AuthService.getAuthHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('Failed league $leagueId');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
