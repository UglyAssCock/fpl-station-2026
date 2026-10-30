import 'package:flutter/material.dart';
import '../config.dart';
import '../models/fpl_models.dart';
import '../services/auth_service.dart';
import '../services/fpl_api_service.dart';
import '../theme.dart';

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  final TextEditingController _leagueIdCtrl = TextEditingController();
  List<LeagueItem> _myLeagues = [];
  FplBootstrapData? _boot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() => _loading = true);
    try {
      final boot = await FplApiService.getBootstrapStatic();
      final entryId = AuthService.currentSession?.entryId ?? 0;
      final entryData = await FplApiService.getEntry(entryId);
      final leaguesObj = entryData['leagues'] as Map<String, dynamic>?;
      final classic = (leaguesObj?['classic'] as List? ?? [])
          .map((e) => LeagueItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _boot = boot;
        _myLeagues = classic;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLeagueById(int id, String title) {
    if (_boot == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeagueStandingsScreen(
          leagueId: id,
          leagueName: title,
          bootstrap: _boot!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _leagueIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Enter any League ID box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inspect Any League by ID',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _leagueIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter Classic League ID (e.g. 314)',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final id = int.tryParse(_leagueIdCtrl.text.trim());
                      if (id != null && id > 0) {
                        _openLeagueById(id, 'League #$id');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'My Classic Leagues',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ..._myLeagues.map((lg) {
          final rankDiff = (lg.entryLastRank ?? 0) - (lg.entryRank ?? 0);
          return Card(
            color: Theme.of(context).cardColor,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _openLeagueById(lg.id, lg.name),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                child: Icon(
                  rankDiff > 0
                      ? Icons.arrow_upward
                      : (rankDiff < 0
                          ? Icons.arrow_downward
                          : Icons.remove),
                  color: rankDiff > 0
                      ? AppColors.emeraldGreen
                      : (rankDiff < 0 ? Colors.redAccent : Colors.grey),
                ),
              ),
              title: Text(lg.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('League ID: ${lg.id}'),
              trailing: Text(
                lg.entryRank != null ? '#${lg.entryRank}' : 'View →',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Page 11: League Standings & Tap a Manager to See Their Team
class LeagueStandingsScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;
  final FplBootstrapData bootstrap;

  const LeagueStandingsScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
    required this.bootstrap,
  });

  @override
  State<LeagueStandingsScreen> createState() => _LeagueStandingsScreenState();
}

class _LeagueStandingsScreenState extends State<LeagueStandingsScreen> {
  List<LeagueStandingRow> _rows = [];
  String _resolvedTitle = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolvedTitle = widget.leagueName;
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    try {
      final data =
          await FplApiService.getLeagueStandings(widget.leagueId);
      final leagueInfo = data['league'] as Map<String, dynamic>?;
      final standings = data['standings'] as Map<String, dynamic>?;
      final results = (standings?['results'] as List? ?? [])
          .map((e) => LeagueStandingRow.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _resolvedTitle = leagueInfo?['name'] ?? widget.leagueName;
        _rows = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _inspectManagerTeam(LeagueStandingRow row) async {
    final gw = widget.bootstrap.currentGameweek.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManagerTeamSheet(
        entryId: row.entry,
        entryName: row.entryName,
        playerName: row.playerName,
        gw: gw,
        bootstrap: widget.bootstrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_resolvedTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final r = _rows[idx];
                    return ListTile(
                      onTap: () => _inspectManagerTeam(r),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryPurple,
                        child: Text(
                          '${r.rank}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        r.entryName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(r.playerName),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r.total} pts',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'GW: ${r.eventTotal}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _ManagerTeamSheet extends StatefulWidget {
  final int entryId;
  final String entryName;
  final String playerName;
  final int gw;
  final FplBootstrapData bootstrap;

  const _ManagerTeamSheet({
    required this.entryId,
    required this.entryName,
    required this.playerName,
    required this.gw,
    required this.bootstrap,
  });

  @override
  State<_ManagerTeamSheet> createState() => _ManagerTeamSheetState();
}

class _ManagerTeamSheetState extends State<_ManagerTeamSheet> {
  List<SquadPick> _picks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await FplApiService.getEntryEventPicks(
          widget.entryId, widget.gw);
      final picks = (data['picks'] as List? ?? [])
          .map((e) => SquadPick.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _picks = picks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      builder: (_, ctrl) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.entryName} (${widget.playerName})',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Gameweek ${widget.gw} Squad Picks',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ..._picks.map((pick) {
              final p = widget.bootstrap.playerById[pick.element];
              if (p == null) return const SizedBox();
              return ListTile(
                leading: PlayerPhoto(
                    playerCode: p.code, width: 36, height: 44),
                title: Text(
                  '${p.webName} ${pick.isCaptain ? "(C)" : pick.isViceCaptain ? "(VC)" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    '${p.positionShort} • ${pick.position <= 11 ? "Starting XI" : "Bench"}'),
                trailing: Text(
                  '${p.eventPoints * pick.multiplier} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
