import 'package:flutter/material.dart';
import '../config.dart';
import '../models/fpl_models.dart';
import '../services/auth_service.dart';
import '../services/fpl_api_service.dart';
import '../theme.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  FplBootstrapData? _boot;
  List<SquadPick> _originalPicks = [];
  List<SquadPick> _simPicks = [];
  List> _latestTransfers = [];
  double _bankTenths = 0; // in tenths, e.g. 15 = £1.5m
  int _freeTransfers = 1;
  int _transfersMadeCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransfersData();
  }

  Future<void> _loadTransfersData() async {
    setState(() => _loading = true);
    try {
      final boot = await FplApiService.getBootstrapStatic();
      final entryId = AuthService.currentSession?.entryId ?? 0;
      final myTeam = await FplApiService.getMyTeam(entryId);
      final historyTransfers =
          await FplApiService.getTransfersLatest(entryId);

      final picksRaw = (myTeam['picks'] as List? ?? [])
          .map((e) => SquadPick.fromJson(e as Map<String, dynamic>))
          .toList();

      final transfersInfo = myTeam['transfers'] as Map<String, dynamic>?;
      final bank = (transfersInfo?['bank'] as int? ?? 10).toDouble();
      final limit = transfersInfo?['limit'] as int? ?? 1;

      if (!mounted) return;
      setState(() {
        _boot = boot;
        _originalPicks = picksRaw
            .map((p) => SquadPick(
                  element: p.element,
                  position: p.position,
                  multiplier: p.multiplier,
                  isCaptain: p.isCaptain,
                  isViceCaptain: p.isViceCaptain,
                ))
            .toList();
        _simPicks = picksRaw;
        _bankTenths = bank;
        _freeTransfers = limit;
        _transfersMadeCount = 0;
        _latestTransfers = historyTransfers;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openReplacementSheet(SquadPick outgoingPick, Player outgoingPlayer) {
    final boot = _boot!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        int? teamFilter;
        double maxPrice = (outgoingPlayer.nowCost + _bankTenths) / 10.0;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentIds = _simPicks.map((e) => e.element).toSet();
            final candidates = boot.players.where((p) {
              if (p.elementType != outgoingPlayer.elementType) return false;
              if (currentIds.contains(p.id)) return false;
              if (p.price > maxPrice) return false;
              if (teamFilter != null && p.teamId != teamFilter) return false;
              if (query.isNotEmpty &&
                  !p.webName.toLowerCase().contains(query.toLowerCase())) {
                return false;
              }
              return true;
            }).toList()
              ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replace ${outgoingPlayer.webName} (${outgoingPlayer.priceString})',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => setModalState(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'Search replacement ${outgoingPlayer.positionShort}...',
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
                          const Text('Max Price: '),
                          Expanded(
                            child: Slider(
                              value: maxPrice.clamp(4.0, 16.0),
                              min: 4.0,
                              max: 16.0,
                              divisions: 24,
                              label: '£${maxPrice.toStringAsFixed(1)}m',
                              onChanged: (v) =>
                                  setModalState(() => maxPrice = v),
                            ),
                          ),
                          Text('£${maxPrice.toStringAsFixed(1)}m'),
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: candidates.length,
                          itemBuilder: (_, i) {
                            final cand = candidates[i];
                            final club = boot.teamById[cand.teamId];
                            return ListTile(
                              leading: PlayerPhoto(
                                  playerCode: cand.code,
                                  width: 38,
                                  height: 48),
                              title: Text(cand.webName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${club?.shortName ?? ''} • Form ${cand.form} • TSB ${cand.selectedByPercent}%'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _bankTenths += (outgoingPlayer.nowCost -
                                        cand.nowCost);
                                    outgoingPick.element = cand.id;
                                    _transfersMadeCount++;
                                  });
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPurple,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(cand.priceString),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _resetSimulation() {
    setState(() {
      _loadTransfersData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _boot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final boot = _boot!;
    final extraTransfers = (_transfersMadeCount - _freeTransfers).clamp(0, 99);
    final pointsHit = extraTransfers * 4;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Budget & Free Transfers Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryPurple, AppColors.deepPurple],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TopBudgetStat(
                  '£${(_bankTenths / 10.0).toStringAsFixed(1)}m', 'In The Bank'),
              _TopBudgetStat('$_freeTransfers', 'Free Transfers'),
              _TopBudgetStat('$_transfersMadeCount', 'Simulated Moves'),
              _TopBudgetStat('-$pointsHit pts', 'Est. Cost'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tap any player to simulate a transfer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: _resetSimulation,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset'),
            ),
          ],
        ),
        ..._simPicks.map((pick) {
          final p = boot.playerById[pick.element];
          if (p == null) return const SizedBox();
          final club = boot.teamById[p.teamId];
          final wasChanged = !_originalPicks.any((o) => o.element == p.id);
          return Card(
            color: wasChanged
                ? AppColors.emeraldGreen.withOpacity(0.18)
                : Theme.of(context).cardColor,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _openReplacementSheet(pick, p),
              leading:
                  PlayerPhoto(playerCode: p.code, width: 38, height: 48),
              title: Text(
                '${p.webName} (${p.positionShort})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                  '${club?.name ?? ''} • Form ${p.form} • ${p.totalPoints} pts'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.priceString,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.swap_horiz,
                      color: AppColors.primaryPurple),
                ],
              ),
            ),
          );
        }),
        if (_latestTransfers.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Recent Account Transfers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ..._latestTransfers.take(8).map((t) {
            final pIn = boot.playerById[t['element_in'] ?? 0];
            final pOut = boot.playerById[t['element_out'] ?? 0];
            final gw = t['event'] ?? '-';
            return ListTile(
              dense: true,
              leading: Text('GW$gw',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text(
                  'OUT: ${pOut?.webName ?? ''}  →  IN: ${pIn?.webName ?? ''}'),
            );
          }),
        ],
      ],
    );
  }
}

class _TopBudgetStat extends StatelessWidget {
  final String val;
  final String label;
  const _TopBudgetStat(this.val, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
