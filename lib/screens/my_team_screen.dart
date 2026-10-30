import 'package:flutter/material.dart';
import '../config.dart';
import '../models/fpl_models.dart';
import '../services/auth_service.dart';
import '../services/fpl_api_service.dart';
import '../theme.dart';
import 'player_detail_screen.dart';

class MyTeamScreen extends StatefulWidget {
  final int initialSubTab; // 0 = My Team Pitch, 1 = Gameweek Points

  const MyTeamScreen({super.key, this.initialSubTab = 0});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  late int _subTab;
  FplBootstrapData? _boot;
  List<SquadPick> _picks = [];
  List<String> _chipsUsed = [];
  Map<int, Map<String, dynamic>> _liveStats = {};
  Map<String, dynamic>? _entryHistory;
  int _selectedGw = 1;
  int? _selectedSwapPosition;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialSubTab;
    _initLoad();
  }

  Future<void> _initLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boot = await FplApiService.getBootstrapStatic();
      final currentGw = boot.currentGameweek.id;
      _selectedGw = currentGw;
      await _loadTeamAndGw(boot, currentGw);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadTeamAndGw(FplBootstrapData boot, int gw) async {
    setState(() => _loading = true);
    try {
      final entryId = AuthService.currentSession?.entryId ?? 0;
      Map<String, dynamic> teamResp;
      if (_subTab == 0) {
        teamResp = await FplApiService.getMyTeam(entryId);
      } else {
        teamResp = await FplApiService.getEntryEventPicks(entryId, gw);
      }

      final picksRaw = teamResp['picks'] as List? ?? [];
      final parsedPicks = picksRaw
          .map((e) => SquadPick.fromJson(e as Map<String, dynamic>))
          .toList();

      final chipsRaw = teamResp['chips'] as List? ?? [];
      final chipsList = <String>[];
      for (final c in chipsRaw) {
        if (c is Map<String, dynamic>) {
          chipsList.add('${c['name']} (${c['status_for_entry'] ?? 'used'})');
        }
      }
      if (teamResp['active_chip'] != null) {
        chipsList.add('Active Chip: ${teamResp['active_chip']}');
      }

      final live = await FplApiService.getEventLive(gw);

      if (!mounted) return;
      setState(() {
        _boot = boot;
        _picks = parsedPicks;
        _chipsUsed = chipsList;
        _liveStats = live;
        _entryHistory = teamResp['entry_history'] as Map<String, dynamic>?;
        _selectedGw = gw;
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

  void _setCaptain(SquadPick target) {
    setState(() {
      for (final p in _picks) {
        if (p.element == target.element) {
          p.isCaptain = true;
          p.isViceCaptain = false;
          p.multiplier = 2;
        } else {
          if (p.isCaptain) {
            p.isCaptain = false;
            p.multiplier = 1;
          }
        }
      }
    });
  }

  void _setViceCaptain(SquadPick target) {
    setState(() {
      for (final p in _picks) {
        p.isViceCaptain = (p.element == target.element);
        if (p.isViceCaptain && p.isCaptain) {
          p.isCaptain = false;
          p.multiplier = 1;
        }
      }
    });
  }

  void _handleSwap(SquadPick tapped) {
    if (_selectedSwapPosition == null) {
      setState(() {
        _selectedSwapPosition = tapped.position;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Now tap another player on the pitch/bench to switch.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final firstIdx =
          _picks.indexWhere((p) => p.position == _selectedSwapPosition);
      final secondIdx =
          _picks.indexWhere((p) => p.position == tapped.position);
      if (firstIdx != -1 && secondIdx != -1 && firstIdx != secondIdx) {
        setState(() {
          final tempElem = _picks[firstIdx].element;
          _picks[firstIdx].element = _picks[secondIdx].element;
          _picks[secondIdx].element = tempElem;
          _selectedSwapPosition = null;
        });
      } else {
        setState(() => _selectedSwapPosition = null);
      }
    }
  }

  void _showPlayerModal(SquadPick pick, Player player) {
    final boot = _boot!;
    final club = boot.teamById[player.teamId];
    final live = _liveStats[player.id] ?? {};
    final gwPts = (live['total_points'] as int? ?? player.eventPoints) *
        (_subTab == 1 ? pick.multiplier : 1);
    final mins = live['minutes'] ?? 0;
    final goals = live['goals_scored'] ?? 0;
    final assists = live['assists'] ?? 0;
    final cs = live['clean_sheets'] ?? 0;
    final bonus = live['bonus'] ?? 0;

    // Modal matching Screenshot 1 Center Popup!
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.firstName,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            player.secondName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ClubBadge(teamCode: club?.code ?? 0, size: 26),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  player.positionFull,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PlayerPhoto(
                        playerCode: player.code, width: 78, height: 95),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ModalMetric(label: 'Form', value: '${player.form}'),
                    _ModalMetric(
                        label: 'Value', value: player.priceString),
                    _ModalMetric(
                        label: 'Selected By',
                        value: '${player.selectedByPercent}%'),
                    _ModalMetric(label: 'GW Pts', value: '$gwPts'),
                  ],
                ),
                const SizedBox(height: 14),
                if (_subTab == 1) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _BreakdownRow('Minutes Played', '$mins'),
                        _BreakdownRow('Goals Scored', '$goals'),
                        _BreakdownRow('Assists', '$assists'),
                        _BreakdownRow('Clean Sheets', '$cs'),
                        _BreakdownRow('Bonus Points', '$bonus'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  const Text(
                    'Set Captain or Vice-Captain',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _setCaptain(pick);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.captainIndigo,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.stars, size: 16),
                          label: const Text('Captain'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _setViceCaptain(pick);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.captainIndigo,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          label: const Text('V.Captain'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleSwap(pick);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Switch Position'),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(
                            player: player,
                            bootstrap: boot,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('View Information'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _boot == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _initLoad,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final boot = _boot!;
    final starters = _picks.where((p) => p.position <= 11).toList();
    final bench = _picks.where((p) => p.position > 11).toList();

    final gkp = starters
        .where((p) => boot.playerById[p.element]?.elementType == 1)
        .toList();
    final def = starters
        .where((p) => boot.playerById[p.element]?.elementType == 2)
        .toList();
    final mid = starters
        .where((p) => boot.playerById[p.element]?.elementType == 3)
        .toList();
    final fwd = starters
        .where((p) => boot.playerById[p.element]?.elementType == 4)
        .toList();

    final gwEvent = boot.events.firstWhere(
      (e) => e.id == _selectedGw,
      orElse: () => boot.currentGameweek,
    );

    int totalGwPoints = _entryHistory?['points'] ?? 0;
    if (totalGwPoints == 0) {
      for (final p in starters) {
        final pts = _liveStats[p.element]?['total_points'] as int? ??
            boot.playerById[p.element]?.eventPoints ??
            0;
        totalGwPoints += pts * p.multiplier;
      }
    }

    return Column(
      children: [
        // Top Toggle: My Team vs Gameweek Points (Screenshot 3 left)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('My Team (Pitch)')),
                      selected: _subTab == 0,
                      onSelected: (v) {
                        if (v) {
                          setState(() => _subTab = 0);
                          _loadTeamAndGw(boot, boot.currentGameweek.id);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Gameweek Points')),
                      selected: _subTab == 1,
                      onSelected: (v) {
                        if (v) {
                          setState(() => _subTab = 1);
                          _loadTeamAndGw(boot, _selectedGw);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_subTab == 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _selectedGw > 1
                          ? () => _loadTeamAndGw(boot, _selectedGw - 1)
                          : null,
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                    ),
                    Text(
                      'Gameweek $_selectedGw',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: _selectedGw < 38
                          ? () => _loadTeamAndGw(boot, _selectedGw + 1)
                          : null,
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _HeaderStat('Final Points', '$totalGwPoints'),
                    _HeaderStat('Highest', '${gwEvent.highestScore}'),
                    _HeaderStat('Average', '${gwEvent.averageEntryScore}'),
                    _HeaderStat(
                        'GW Rank', '${_entryHistory?['rank'] ?? '--'}'),
                  ],
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Chips Status Banner
              if (_chipsUsed.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Chips Status: ${_chipsUsed.join(' • ')}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),

              // Green Football Pitch View (Screenshot 3)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppAssetImage(
                        fileName: 'pitch_bg.png',
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: AppColors.emeraldGreen,
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _PitchLinesPainter(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 6),
                        child: Column(
                          children: [
                            _buildPitchRow(gkp, boot),
                            const SizedBox(height: 16),
                            _buildPitchRow(def, boot),
                            const SizedBox(height: 16),
                            _buildPitchRow(mid, boot),
                            const SizedBox(height: 16),
                            _buildPitchRow(fwd, boot),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bench Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Substitutes Bench',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPitchRow(bench, boot),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPitchRow(List<SquadPick> rowPicks, FplBootstrapData boot) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: rowPicks.map((pick) {
        final player = boot.playerById[pick.element];
        if (player == null) return const SizedBox();
        final live = _liveStats[player.id];
        final rawPts =
            live?['total_points'] as int? ?? player.eventPoints;
        final displayPts = _subTab == 1 ? rawPts * pick.multiplier : rawPts;
        final isSelectedForSwap = _selectedSwapPosition == pick.position;

        return GestureDetector(
          onTap: () => _showPlayerModal(pick, player),
          child: Container(
            width: 72,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelectedForSwap
                  ? Border.all(color: Colors.yellowAccent, width: 2)
                  : null,
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    PlayerPhoto(
                        playerCode: player.code, width: 52, height: 62),
                    if (pick.isCaptain || pick.isViceCaptain)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: AppColors.captainIndigo,
                          child: Text(
                            pick.isCaptain ? 'C' : 'V',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: Text(
                    player.webName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.captainIndigo,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(4)),
                  ),
                  child: Text(
                    _subTab == 1 ? '$displayPts pts' : player.priceString,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ModalMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ModalMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  const _BreakdownRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black87, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _PitchLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Outer border
    canvas.drawRect(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
      paint,
    );
    // Top penalty box
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.22, 10, size.width * 0.56, 65),
      paint,
    );
    // Halfway line & circle
    canvas.drawLine(
      Offset(10, size.height * 0.5),
      Offset(size.width - 10, size.height * 0.5),
      paint,
    );
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5), 36, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
