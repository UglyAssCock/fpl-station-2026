import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../models/fpl_models.dart';
import '../services/auth_service.dart';
import '../services/fpl_api_service.dart';
import '../theme.dart';
import 'more_screen.dart';
import 'player_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToMyTeam;
  final VoidCallback onNavigateToPoints;

  const HomeScreen({
    super.key,
    required this.onNavigateToMyTeam,
    required this.onNavigateToPoints,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FplBootstrapData? _boot;
  Map<String, dynamic>? _entryData;
  bool _loading = true;
  String? _error;
  Timer? _countdownTimer;
  Duration _timeUntilDeadline = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    if (_boot == null) return;
    final nextGw = _boot!.nextGameweek;
    if (nextGw.deadlineTime.isEmpty) return;
    final deadline = DateTime.tryParse(nextGw.deadlineTime);
    if (deadline == null) return;
    final diff = deadline.difference(DateTime.now().toUtc());
    if (mounted) {
      setState(() {
        _timeUntilDeadline = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  Future<void> _loadData({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boot =
          await FplApiService.getBootstrapStatic(forceRefresh: force);
      final entryId = AuthService.currentSession?.entryId ?? 0;
      Map<String, dynamic>? entry;
      if (entryId > 0) {
        entry = await FplApiService.getEntry(entryId);
      }
      if (!mounted) return;
      setState(() {
        _boot = boot;
        _entryData = entry;
        _loading = false;
      });
      _updateCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatCountdown(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    return '${days}d ${hours}h ${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _boot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error loading FPL data:\n$_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadData(force: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final boot = _boot!;
    final gw = boot.currentGameweek;
    final session = AuthService.currentSession;
    final firstName = session?.firstName ?? 'Manager';
    final latestPoints = _entryData?['summary_event_points'] ?? 0;
    final gwRank = _entryData?['summary_event_rank'] ?? 0;
    final overallPoints = _entryData?['summary_overall_points'] ?? 0;
    final overallRank = _entryData?['summary_overall_rank'] ?? 0;
    final lastDeadlineValue =
        ((_entryData?['last_deadline_value'] ?? 1000) as int) / 10.0;
    final numberFmt = NumberFormat('#,###');

    final mostTransferredInPlayer =
        boot.playerById[gw.mostTransferredIn ?? 0];
    final mostCaptainedPlayer = boot.playerById[gw.mostCaptained ?? 0];

    // Top Dream Team players for current gameweek
    final dreamTeamPlayers = List<Player>.from(boot.players)
      ..sort((a, b) => b.eventPoints.compareTo(a.eventPoints));
    final topDream = dreamTeamPlayers.take(6).toList();

    // Top ownership injury/news alerts
    final newsPlayers = boot.players
        .where((p) => p.news.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.selectedByPercent.compareTo(a.selectedByPercent));

    return RefreshIndicator(
      onRefresh: () => _loadData(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Header Greeting matching Screenshot 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $firstName',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NotificationsScreen(bootstrap: boot),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  IconButton(
                    tooltip: 'Players Database',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerListScreen(bootstrap: boot),
                        ),
                      );
                    },
                    icon: const Icon(Icons.grid_view_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hero Purple Gameweek Card (Screenshot 2)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppAssetImage(
                    fileName: 'home_banner.png',
                    fit: BoxFit.cover,
                    fallback: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryPurple,
                            AppColors.deepPurple,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryPurple.withOpacity(0.88),
                        AppColors.deepPurple.withOpacity(0.92),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gw.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deadline Countdown: ${_formatCountdown(_timeUntilDeadline)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: widget.onNavigateToMyTeam,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('My Team →',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStatItem(
                              value: '$latestPoints',
                              label: 'Latest Points',
                            ),
                          ),
                          Expanded(
                            child: _HeroStatItem(
                              value: gwRank > 0
                                  ? numberFmt.format(gwRank)
                                  : '--',
                              label: 'Gameweek Rank',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStatItem(
                              value: '${gw.averageEntryScore}',
                              label: 'Average Points',
                            ),
                          ),
                          Expanded(
                            child: _HeroStatItem(
                              value: '${gw.highestScore}',
                              label: 'Highest Points',
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overall Points: $overallPoints',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          Text(
                            'Overall Rank: ${overallRank > 0 ? numberFmt.format(overallRank) : '--'}',
                            style: const TextStyle(
                                color: AppColors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Action Pills (GW Points & Live Matches)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onNavigateToPoints,
                  icon: const Icon(Icons.assessment_outlined, size: 18),
                  label: const Text('GW Points'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveMatchesScreen(bootstrap: boot),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Live Matches'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Green Gameweek Details Card + Orange Squad Value Card (Screenshot 2)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${gw.name} Details',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Text(
                'Squad & Value',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
           IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SmallCardStat(
                                value: numberFmt.format(gw.transfersMade),
                                label: 'Transfers Made',
                              ),
                            ),
                            Expanded(
                              child: _SmallCardStat(
                                value:
                                    mostTransferredInPlayer?.webName ?? 'N/A',
                                label: 'Most Transferred In',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _SmallCardStat(
                                value: numberFmt.format(gw.chipPlaysCount),
                                label: 'Chips Played',
                              ),
                            ),
                            Expanded(
                              child: _SmallCardStat(
                                value: mostCaptainedPlayer?.webName ?? 'N/A',
                                label: 'Most Captained',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.amberOrange,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SmallCardStat(
                          value: '${gw.id}/38',
                          label: 'Gameweek',
                        ),
                        const SizedBox(height: 14),
                        _SmallCardStat(
                          value: '£${lastDeadlineValue.toStringAsFixed(1)}m',
                          label: 'Squad Value',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dream Team Strip (Screenshot 2 & 3)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${gw.name} Top Scorers',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerListScreen(bootstrap: boot),
                    ),
                  );
                },
                child: const Text('All Players →'),
              ),
            ],
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topDream.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final p = topDream[idx];
                final club = boot.teamById[p.teamId];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerDetailScreen(
                          player: p,
                          bootstrap: boot,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ClubBadge(teamCode: club?.code ?? 0, size: 22),
                            PlayerPhoto(
                                playerCode: p.code, width: 44, height: 54),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          p.webName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${p.eventPoints} pts',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.positionShort,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Latest News & Injuries Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Headline Injury & Squad News',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewsInjuriesScreen(bootstrap: boot),
                    ),
                  );
                },
                child: const Text('See All →'),
              ),
            ],
          ),
          ...newsPlayers.take(5).map((p) {
            final club = boot.teamById[p.teamId];
            return Card(
              color: Theme.of(context).cardColor,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerDetailScreen(player: p, bootstrap: boot),
                    ),
                  );
                },
                leading: PlayerPhoto(playerCode: p.code, width: 38, height: 48),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.webName} (${club?.shortName ?? ''})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${p.selectedByPercent}% TSB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.amberOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  p.news,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SmallCardStat extends StatelessWidget {
  final String value;
  final String label;

  const _SmallCardStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
