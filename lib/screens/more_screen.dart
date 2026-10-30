import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/fpl_models.dart';
import '../services/auth_service.dart';
import '../services/fpl_api_service.dart';
import '../theme.dart';
import 'player_detail_screen.dart';

class MoreScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MoreScreen({super.key, required this.onLogout});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  FplBootstrapData? _boot;
  Map<String, dynamic>? _entry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await FplApiService.getBootstrapStatic();
      final id = AuthService.currentSession?.entryId ?? 0;
      final e = id > 0 ? await FplApiService.getEntry(id) : null;
      if (mounted) {
        setState(() {
          _boot = b;
          _entry = e;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.currentSession;
    final teamName = _entry?['name'] ?? 'My FPL Squad';
    final boot = _boot;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryPurple, AppColors.deepPurple],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppAssetImage(
                  fileName: 'logo.png',
                  width: 56,
                  height: 56,
                  fallback: const Icon(Icons.account_circle,
                      size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${session?.fullName ?? 'Manager'} • ID #${session?.entryId ?? ''}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Toggle Light / Dark Theme',
                onPressed: () => ThemeController.toggleTheme(),
                icon: const Icon(Icons.brightness_6, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (boot == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          _MenuTile(
            icon: Icons.people_alt_outlined,
            title: 'Players Database & Stats',
            subtitle: 'Sort & filter by position, price, form, TSB%',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PlayerListScreen(bootstrap: boot)),
            ),
          ),
          _MenuTile(
            icon: Icons.grid_on_rounded,
            title: 'Fixtures & FDR Color Grid',
            subtitle: '2026/27 match schedule & 5-GW difficulty matrix',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FixturesFdrScreen(bootstrap: boot)),
            ),
          ),
          _MenuTile(
            icon: Icons.shield_outlined,
            title: 'Premier League Clubs (20)',
            subtitle: 'Inspect all 20 club squads, badges & form',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ClubsScreen(bootstrap: boot)),
            ),
          ),
          _MenuTile(
            icon: Icons.bolt,
            title: 'Live Matches & My Live Points',
            subtitle: 'Real-time scores and live gameweek player points',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LiveMatchesScreen(bootstrap: boot)),
            ),
          ),
          _MenuTile(
            icon: Icons.event_note_outlined,
            title: 'Gameweek Planner (Local)',
            subtitle: 'Plan future gameweek captaincy & transfer notes',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LocalPlannerScreen(bootstrap: boot)),
            ),
          ),
          _MenuTile(
            icon: Icons.memory,
            title: 'Chips Guide & Status',
            subtitle: 'Wildcard, Free Hit, Bench Boost, Triple Captain',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChipsStatusScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.medical_services_outlined,
            title: 'News & Injuries (By Ownership)',
            subtitle: 'Injured, doubtful & suspended players by TSB%',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NewsInjuriesScreen(bootstrap: boot)),
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'In-App Notifications',
            subtitle: 'Deadlines, squad flags & high-ownership alerts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NotificationsScreen(bootstrap: boot)),
            ),
          ),
        ],
        const Divider(height: 28),
        SwitchListTile(
          title: const Text('Dark Mode Theme',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle:
              const Text('Switch between Station Dark Navy & Clean White'),
          value: ThemeController.themeMode.value == ThemeMode.dark,
          onChanged: (_) {
            ThemeController.toggleTheme();
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await AuthService.logout();
            widget.onLogout();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Logout of FPL Account',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryPurple.withOpacity(0.18),
          child: Icon(icon, color: AppColors.primaryPurple),
        ),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class FixturesFdrScreen extends StatefulWidget {
  final FplBootstrapData bootstrap;
  const FixturesFdrScreen({super.key, required this.bootstrap});

  @override
  State<FixturesFdrScreen> createState() => _FixturesFdrScreenState();
}

class _FixturesFdrScreenState extends State<FixturesFdrScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<FixtureItem> _allFixtures = [];
  int _selectedGw = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedGw = widget.bootstrap.currentGameweek.id;
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await FplApiService.getFixtures();
      if (mounted) {
        setState(() {
          _allFixtures = f;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startGw = widget.bootstrap.currentGameweek.id;
    final gws =
        List.generate(5, (i) => (startGw + i) <= 38 ? (startGw + i) : 38);
    final gwFixtures =
        _allFixtures.where((f) => f.event == _selectedGw).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixtures & FDR Grid'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'GW Fixtures'),
            Tab(text: 'FDR Color Grid'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _selectedGw > 1
                              ? () => setState(() => _selectedGw--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Gameweek $_selectedGw',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          onPressed: _selectedGw < 38
                              ? () => setState(() => _selectedGw++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: gwFixtures.length,
                        itemBuilder: (_, i) {
                          final fx = gwFixtures[i];
                          final th = widget.bootstrap.teamById[fx.teamH];
                          final ta = widget.bootstrap.teamById[fx.teamA];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            child: ListTile(
                              leading:
                                  ClubBadge(teamCode: th?.code ?? 0, size: 28),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(th?.shortName ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      fx.started
                                          ? '${fx.teamHScore ?? 0} - ${fx.teamAScore ?? 0}'
                                          : 'vs',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(ta?.shortName ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              trailing:
                                  ClubBadge(teamCode: ta?.code ?? 0, size: 28),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: widget.bootstrap.teams.map((club) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 78,
                              child: Row(
                                children: [
                                  ClubBadge(teamCode: club.code, size: 22),
                                  const SizedBox(width: 6),
                                  Text(club.shortName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            ...gws.map((gwNum) {
                              final match = _allFixtures.firstWhere(
                                (f) =>
                                    f.event == gwNum &&
                                    (f.teamH == club.id || f.teamA == club.id),
                                orElse: () => FixtureItem(
                                  id: 0,
                                  event: gwNum,
                                  kickoffTime: '',
                                  teamH: 0,
                                  teamA: 0,
                                  teamHScore: null,
                                  teamAScore: null,
                                  teamHDifficulty: 3,
                                  teamADifficulty: 3,
                                  started: false,
                                  finished: false,
                                  minutes: 0,
                                ),
                              );
                              if (match.id == 0) {
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    height: 34,
                                    alignment: Alignment.center,
                                    color: Colors.grey.withOpacity(0.2),
                                    child: const Text('-',
                                        style: TextStyle(fontSize: 11)),
                                  ),
                                );
                              }
                              final isHome = match.teamH == club.id;
                              final opp = widget.bootstrap.teamById[
                                  isHome ? match.teamA : match.teamH];
                              final diff = isHome
                                  ? match.teamHDifficulty
                                  : match.teamADifficulty;
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.fdrColor(diff),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${opp?.shortName ?? ''}${isHome ? "(H)" : "(A)"}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class ClubsScreen extends StatelessWidget {
  final FplBootstrapData bootstrap;
  const ClubsScreen({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premier League Clubs (2026/27)')),
      body: ListView.builder(
        itemCount: bootstrap.teams.length,
        itemBuilder: (context, idx) {
          final club = bootstrap.teams[idx];
          final squad = bootstrap.players
              .where((p) => p.teamId == club.id)
              .toList()
            ..sort((a, b) => b.form.compareTo(a.form));
          final avgForm = squad.isEmpty
              ? 0.0
              : squad.map((e) => e.form).reduce((a, b) => a + b) / squad.length;

          return ExpansionTile(
            leading: ClubBadge(teamCode: club.code, size: 32),
            title: Text(club.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Strength: ${club.strength}/5 • Squad Avg Form: ${avgForm.toStringAsFixed(1)}'),
            children: squad.map((p) {
              return ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerDetailScreen(player: p, bootstrap: bootstrap),
                  ),
                ),
                leading: PlayerPhoto(playerCode: p.code, width: 34, height: 42),
                title: Text(p.webName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${p.positionShort} • Form ${p.form} • ${p.priceString}'),
                trailing: Text('${p.totalPoints} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class LiveMatchesScreen extends StatefulWidget {
  final FplBootstrapData bootstrap;
  const LiveMatchesScreen({super.key, required this.bootstrap});

  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen> {
  List<FixtureItem> _gwFixtures = [];
  Map<int, Map<String, dynamic>> _liveStats = {};
  List<SquadPick> _myPicks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLive();
  }

  Future<void> _loadLive() async {
    try {
      final gw = widget.bootstrap.currentGameweek.id;
      final fx = await FplApiService.getFixtures(eventId: gw);
      final live = await FplApiService.getEventLive(gw);
      final entryId = AuthService.currentSession?.entryId ?? 0;
      final myTeam = await FplApiService.getEntryEventPicks(entryId, gw);
      final picks = (myTeam['picks'] as List? ?? [])
          .map((e) => SquadPick.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _gwFixtures = fx;
          _liveStats = live;
          _myPicks = picks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gw = widget.bootstrap.currentGameweek;
    return Scaffold(
      appBar: AppBar(title: Text('Live Centre • ${gw.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'My Players Live Gameweek Points',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._myPicks.map((pick) {
                  final p = widget.bootstrap.playerById[pick.element];
                  if (p == null) return const SizedBox();
                  final st = _liveStats[p.id] ?? {};
                  final pts =
                      (st['total_points'] as int? ?? p.eventPoints) *
                          pick.multiplier;
                  final mins = st['minutes'] ?? 0;
                  final bps = st['bps'] ?? 0;
                  return ListTile(
                    dense: true,
                    leading:
                        PlayerPhoto(playerCode: p.code, width: 34, height: 42),
                    title: Text(
                      '${p.webName} ${pick.isCaptain ? "(C)" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$mins mins • BPS: $bps'),
                    trailing: Text(
                      '$pts pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldGreen,
                        fontSize: 15,
                      ),
                    ),
                  );
                }),
                const Divider(height: 28),
                const Text(
                  'Live Gameweek Fixtures',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._gwFixtures.map((f) {
                  final th = widget.bootstrap.teamById[f.teamH];
                  final ta = widget.bootstrap.teamById[f.teamA];
                  return Card(
                    child: ListTile(
                      leading: ClubBadge(teamCode: th?.code ?? 0, size: 26),
                      title: Text(
                        '${th?.shortName ?? ''}  ${f.teamHScore ?? 0} - ${f.teamAScore ?? 0}  ${ta?.shortName ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        f.finished
                            ? 'Full-Time'
                            : (f.started ? 'Live (${f.minutes}\')' : 'Upcoming'),
                        textAlign: TextAlign.center,
                      ),
                      trailing: ClubBadge(teamCode: ta?.code ?? 0, size: 26),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class LocalPlannerScreen extends StatefulWidget {
  final FplBootstrapData bootstrap;
  const LocalPlannerScreen({super.key, required this.bootstrap});

  @override
  State<LocalPlannerScreen> createState() => _LocalPlannerScreenState();
}

class _LocalPlannerScreenState extends State<LocalPlannerScreen> {
  final TextEditingController _noteCtrl = TextEditingController();
  List> _plans = [];
  int _gw = 1;

  @override
  void initState() {
    super.initState();
    _gw = widget.bootstrap.nextGameweek.id;
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('fpl_local_plans');
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      setState(() => _plans = list);
    }
  }

  Future<void> _addPlan() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() {
      _plans.add({'gw': 'GW$_gw', 'note': _noteCtrl.text.trim()});
      _noteCtrl.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fpl_local_plans', jsonEncode(_plans));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gameweek Transfer & Chip Planner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                DropdownButton<int>(
                  value: _gw,
                  items: List.generate(
                    38,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('GW ${i + 1}')),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => _gw = v);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Roll FT, Captain Salah...',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addPlan,
                  icon: const Icon(Icons.add_circle,
                      color: AppColors.primaryPurple),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _plans.length,
                itemBuilder: (_, idx) {
                  final item = _plans[idx];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryPurple,
                        child: Text(item['gw'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                      title: Text(item['note'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          setState(() => _plans.removeAt(idx));
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                              'fpl_local_plans', jsonEncode(_plans));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChipsStatusScreen extends StatefulWidget {
  const ChipsStatusScreen({super.key});

  @override
  State<ChipsStatusScreen> createState() => _ChipsStatusScreenState();
}

class _ChipsStatusScreenState extends State<ChipsStatusScreen> {
  Map<String, String> _chipStatus = {};
  bool _loading = true;

  static const List> _chipDefs = [
    {
      'key': 'wildcard',
      'title': 'Wildcard',
      'desc':
          'Make unlimited permanent transfers in a single Gameweek free of points deductions (two per season).'
    },
    {
      'key': 'freehit',
      'title': 'Free Hit',
      'desc':
          'Make unlimited transfers for a single Gameweek only. Your squad reverts to its previous state next GW.'
    },
    {
      'key': 'bboost',
      'title': 'Bench Boost',
      'desc':
          'The points scored by your 4 bench substitutes are included in your total for that Gameweek.'
    },
    {
      'key': '3xc',
      'title': 'Triple Captain',
      'desc':
          'Your Captain points are multiplied by 3 instead of 2 for that Gameweek.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadChips();
  }

  Future<void> _loadChips() async {
    try {
      final entryId = AuthService.currentSession?.entryId ?? 0;
      final data = await FplApiService.getMyTeam(entryId);
      final rawChips = data['chips'];
      final map = <String, String>{};
      if (rawChips is Iterable) {
        for (final c in rawChips) {
          if (c is Map<String, dynamic>) {
            map[c['name'].toString()] =
                c['status_for_entry']?.toString() ?? 'available';
          }
        }
      }
      if (mounted) {
        setState(() {
          _chipStatus = map;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FPL Chips Guide & Status')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _chipDefs.map((c) {
                final status =
                    (_chipStatus[c['key']] ?? 'available').toUpperCase();
                final isAvail = status == 'AVAILABLE';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(c['title']!,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(c['desc']!),
                    ),
                    trailing: Chip(
                      backgroundColor: isAvail
                          ? AppColors.emeraldGreen.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      label: Text(
                        status,
                        style: TextStyle(
                          color:
                              isAvail ? AppColors.emeraldGreen : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class NewsInjuriesScreen extends StatelessWidget {
  final FplBootstrapData bootstrap;
  const NewsInjuriesScreen({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    final flagged = bootstrap.players
        .where((p) => p.news.trim().isNotEmpty || p.status != 'a')
        .toList()
      ..sort((a, b) => b.selectedByPercent.compareTo(a.selectedByPercent));

    return Scaffold(
      appBar: AppBar(title: const Text('Injuries & Bans (By Ownership)')),
      body: ListView.builder(
        itemCount: flagged.length,
        itemBuilder: (context, idx) {
          final p = flagged[idx];
          final club = bootstrap.teamById[p.teamId];
          final chance = p.chanceOfPlayingNextRound ?? 100;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PlayerDetailScreen(player: p, bootstrap: bootstrap),
                ),
              ),
              leading: PlayerPhoto(playerCode: p.code, width: 40, height: 50),
              title: Text(
                '${p.webName} (${club?.shortName ?? ''}) • ${p.selectedByPercent}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(p.news.isNotEmpty ? p.news : 'Flagged status'),
              trailing: CircleAvatar(
                radius: 18,
                backgroundColor:
                    chance <= 25 ? Colors.redAccent : AppColors.amberOrange,
                child: Text(
                  '$chance%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  final FplBootstrapData bootstrap;
  const NotificationsScreen({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    final nextGw = bootstrap.nextGameweek;
    final highOwnedInjuries = bootstrap.players
        .where((p) => p.news.isNotEmpty && p.selectedByPercent >= 10.0)
        .toList()
      ..sort((a, b) => b.selectedByPercent.compareTo(a.selectedByPercent));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications & Alerts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.primaryPurple.withOpacity(0.2),
            child: ListTile(
              leading: const Icon(Icons.alarm, color: AppColors.primaryPurple),
              title: Text('${nextGw.name} Deadline Reminder',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Official UTC Deadline: ${nextGw.deadlineTime}'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'High-Ownership Injury & Suspension Alerts (>10% TSB)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...highOwnedInjuries.map((p) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.amberOrange),
                title: Text('${p.webName} (${p.selectedByPercent}% owned)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p.news),
              ),
            );
          }),
        ],
      ),
    );
  }
}
