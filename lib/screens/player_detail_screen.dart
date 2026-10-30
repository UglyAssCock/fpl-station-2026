import 'package:flutter/material.dart';
import '../config.dart';
import '../models/fpl_models.dart';
import '../services/fpl_api_service.dart';
import '../theme.dart';

/// Page 6: Full Player List with Sort & Filter by Position, Price, Form, Ownership
class PlayerListScreen extends StatefulWidget {
  final FplBootstrapData bootstrap;

  const PlayerListScreen({super.key, required this.bootstrap});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  String _search = '';
  int _selectedPos = 0; // 0=All, 1=GKP, 2=DEF, 3=MID, 4=FWD
  String _sortBy = 'points'; // points, price, form, ownership

  @override
  Widget build(BuildContext context) {
    var list = widget.bootstrap.players.where((p) {
      if (_selectedPos != 0 && p.elementType != _selectedPos) return false;
      if (_search.isNotEmpty &&
          !p.webName.toLowerCase().contains(_search.toLowerCase()) &&
          !p.secondName.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'price':
          return b.nowCost.compareTo(a.nowCost);
        case 'form':
          return b.form.compareTo(a.form);
        case 'ownership':
          return b.selectedByPercent.compareTo(a.selectedByPercent);
        default:
          return b.totalPoints.compareTo(a.totalPoints);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Players Database (2026/27)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search player name...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _PosChip('ALL', 0),
                            _PosChip('GKP', 1),
                            _PosChip('DEF', 2),
                            _PosChip('MID', 3),
                            _PosChip('FWD', 4),
                          ],
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'points', child: Text('Sort: Points')),
                        DropdownMenuItem(
                            value: 'price', child: Text('Sort: Price')),
                        DropdownMenuItem(
                            value: 'form', child: Text('Sort: Form')),
                        DropdownMenuItem(
                            value: 'ownership', child: Text('Sort: TSB%')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sortBy = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, idx) {
                final p = list[idx];
                final club = widget.bootstrap.teamById[p.teamId];
                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerDetailScreen(
                          player: p,
                          bootstrap: widget.bootstrap,
                        ),
                      ),
                    );
                  },
                  leading:
                      PlayerPhoto(playerCode: p.code, width: 42, height: 52),
                  title: Text(
                    p.webName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      '${club?.shortName ?? ''} • ${p.positionShort} • Form ${p.form} • ${p.selectedByPercent}%'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.totalPoints} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      Text(p.priceString,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _PosChip(String label, int val) {
    final sel = _selectedPos == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _selectedPos = val),
      ),
    );
  }
}

/// Page 7: Player Detail Screen (Matches Screenshot 1 Left & Right Screens)
class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  final FplBootstrapData bootstrap;

  const PlayerDetailScreen({
    super.key,
    required this.player,
    required this.bootstrap,
  });

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final data =
          await FplApiService.getElementSummary(widget.player.id);
      if (!mounted) return;
      setState(() {
        _summary = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final club = widget.bootstrap.teamById[p.teamId];
    final history = (_summary?['history'] as List? ?? []);
    final fixtures = (_summary?['fixtures'] as List? ?? []);

    return Scaffold(
      appBar: AppBar(title: Text(p.webName)),
      body: Column(
        children: [
          // Top Header with Player Photo & Club Badge (Screenshot 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.firstName,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        p.secondName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ClubBadge(teamCode: club?.code ?? 0, size: 34),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.positionFull,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PlayerPhoto(playerCode: p.code, width: 110, height: 135),
              ],
            ),
          ),

          if (p.news.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amberOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '⚠️ ${p.news}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

          // Purple 5-Stat Bar (Form | GW | Points | Value | TSB%) matching Screenshot 1
          Container(
            color: AppColors.primaryPurple,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _RibbonStat('${p.form}', 'Form'),
                _RibbonStat('${p.eventPoints}', 'GW Pts'),
                _RibbonStat('${p.totalPoints}', 'Points'),
                _RibbonStat(p.priceString, 'Value'),
                _RibbonStat('${p.selectedByPercent}%', 'TSB'),
              ],
            ),
          ),

          // History & Fixtures Tabs (Screenshot 1)
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryPurple,
            tabs: const [
              Tab(text: 'History'),
              Tab(text: 'Fixtures'),
            ],
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Match History & Points Breakdown (Screenshot 1 Right)
                      ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, idx) {
                          final h =
                              history[history.length - 1 - idx] as Map<String, dynamic>;
                          final oppTeam =
                              widget.bootstrap.teamById[h['opponent_team'] ?? 0];
                          final wasHome = h['was_home'] == true;
                          final hScore = h['team_h_score'] ?? 0;
                          final aScore = h['team_a_score'] ?? 0;
                          final totalPts = h['total_points'] ?? 0;
                          final round = h['round'] ?? 1;

                          return ExpansionTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('GW$round',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text(wasHome
                                        ? (club?.shortName ?? '')
                                        : (oppTeam?.shortName ?? '')),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryPurple,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$hScore - $aScore',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(wasHome
                                        ? (oppTeam?.shortName ?? '')
                                        : (club?.shortName ?? '')),
                                  ],
                                ),
                                Text(
                                  '$totalPts pts',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Column(
                                  children: [
                                    _StatDetailRow(
                                        'Minutes Played', '${h['minutes']}'),
                                    _StatDetailRow(
                                        'Goals Scored', '${h['goals_scored']}'),
                                    _StatDetailRow(
                                        'Assists', '${h['assists']}'),
                                    _StatDetailRow(
                                        'Clean Sheets', '${h['clean_sheets']}'),
                                    _StatDetailRow('Bonus', '${h['bonus']}'),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Tab 2: Upcoming Fixtures + FDR Badge (Screenshot 1 Left)
                      ListView.separated(
                        itemCount: fixtures.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final f = fixtures[idx] as Map<String, dynamic>;
                          final isHome = f['is_home'] == true;
                          final oppId =
                              isHome ? f['team_a'] : f['team_h'];
                          final oppClub =
                              widget.bootstrap.teamById[oppId ?? 0];
                          final diff = f['difficulty'] as int? ?? 3;
                          final ev = f['event'] ?? '-';

                          return ListTile(
                            leading: Text(
                              'GW$ev',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isHome
                                    ? (club?.name ?? '')
                                    : (oppClub?.name ?? '')),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('vs',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                Text(isHome
                                    ? (oppClub?.name ?? '')
                                    : (club?.name ?? '')),
                              ],
                            ),
                            trailing: Container(
                              width: 32,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.fdrColor(diff),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$diff',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),

          // Bottom Summary Bar (Assists & Goals matching Screenshot 1 Right)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  '⚽ ${p.goalsScored} Goals',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryPurple,
                  ),
                ),
                Text(
                  '👟 ${p.assists} Assists',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryPurple,
                  ),
                ),
                Text(
                  '🛡️ ${p.cleanSheets} CS',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.emeraldGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RibbonStat extends StatelessWidget {
  final String value;
  final String label;
  const _RibbonStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
