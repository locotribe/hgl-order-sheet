import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/week.dart';
import '../services/app_state.dart';
import '../services/repositories/attendance_repository.dart';
import '../services/repositories/player_repository.dart';
import '../services/repositories/week_repository.dart';
import 'admin_gate_screen.dart';
import 'attendance_screen.dart';
import 'result_sheet_screen.dart';

/// 画面1：個人トップ（マイページ）— SPEC.md §4
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _weekRepository = WeekRepository();
  final _playerRepository = PlayerRepository();
  final _attendanceRepository = AttendanceRepository();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myId = appState.currentPlayer!.id;

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: StreamBuilder<Player?>(
        stream: _playerRepository.watchById(myId),
        initialData: appState.currentPlayer,
        builder: (context, playerSnap) {
          final player = playerSnap.data ?? appState.currentPlayer!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileCard(player: player),
              const SizedBox(height: 16),
              _StatsCard(player: player),
              const SizedBox(height: 16),
              StreamBuilder<List<Player>>(
                stream: _playerRepository.watchAll(),
                builder: (context, allSnap) {
                  final all = allSnap.data;
                  if (all == null || all.isEmpty) return const SizedBox.shrink();
                  final ranked = [...all]
                    ..sort((a, b) => b.winRate.compareTo(a.winRate));
                  final rank = ranked.indexWhere((p) => p.id == player.id) + 1;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('チーム内順位: $rank位 / ${ranked.length}人中'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<Week?>(
                stream: _weekRepository.watchCurrentWeek(),
                builder: (context, weekSnap) {
                  final week = weekSnap.data;
                  if (week == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('今週の試合予定はまだ登録されていません。'),
                      ),
                    );
                  }
                  return _ThisWeekCard(
                    week: week,
                    playerId: myId,
                    attendanceRepository: _attendanceRepository,
                  );
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('リザルトシートを見る'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResultSheetScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock),
                label: const Text('管理者メニュー'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminGateScreen()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                player.kanjiName.isNotEmpty ? player.kanjiName[0] : '?',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.kanjiName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('レーティング: ${player.rating.toStringAsFixed(2)}'),
                  if (player.isProvisional)
                    const Text(
                      '※ 実データ未取得のため暫定レートです',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    final games = player.winLossByGame.values;
    final wins = games.fold<int>(0, (sum, g) => sum + g.wins);
    final losses = games.fold<int>(0, (sum, g) => sum + g.losses);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('スタッツ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('01スタッツ: ${player.effectiveStats01.toStringAsFixed(2)}'),
                Text('クリケットスタッツ: ${player.effectiveStatsCricket.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('通算: $wins勝 $losses敗'),
                Text('勝率: ${(player.winRate * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({
    required this.week,
    required this.playerId,
    required this.attendanceRepository,
  });

  final Week week;
  final String playerId;
  final AttendanceRepository attendanceRepository;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今週の試合', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('対戦相手: ${week.opponentTeam}'),
            Text(week.homeAway == HomeAway.home ? 'HOME' : 'AWAY'),
            Text('日時: ${week.date.year}/${week.date.month}/${week.date.day}'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: () async {
                    await attendanceRepository.setPresent(
                      weekId: week.id,
                      playerId: playerId,
                      present: true,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('参加登録しました')),
                      );
                    }
                  },
                  child: const Text('参加する'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                    );
                  },
                  child: const Text('出席状況を見る'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
