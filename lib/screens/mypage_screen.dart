// [修正] トグル式出欠ボタンとオーダーシート表記の変更 (v.1.2)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../models/player.dart';
import '../models/week.dart';
import '../services/app_state.dart';
import '../services/repositories/attendance_repository.dart';
import '../services/repositories/player_repository.dart';
import '../services/repositories/week_repository.dart';
import '../widgets/match_info_card.dart';
import 'admin_gate_screen.dart';
import 'attendance_screen.dart';
import 'result_sheet_screen.dart';

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
                      child: Text('チーム内ランキング : $rank 位 / ${ranked.length}人'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('今週の試合', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              StreamBuilder<Week?>(
                stream: _weekRepository.watchCurrentWeek(),
                builder: (context, weekSnap) {
                  final week = weekSnap.data;
                  if (week == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('今週の試合情報がありません'),
                      ),
                    );
                  }

                  // 自分自身の出欠状況をリアルタイム購読
                  return StreamBuilder<List<Attendance>>(
                    stream: _attendanceRepository.watchAll(week.id),
                    builder: (context, attSnap) {
                      final attendanceList = attSnap.data ?? [];
                      // 自分の参加状態を取得
                      final myAttendance = attendanceList.where((a) => a.playerId == myId).firstOrNull;
                      final isPresent = myAttendance?.present ?? false;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MatchInfoCard(week: week),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // トグル処理（参加↔不参加を切り替え）
                                    final newState = !isPresent;
                                    await _attendanceRepository.setPresent(
                                      weekId: week.id,
                                      playerId: myId,
                                      present: newState,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(newState ? '参加を記録しました' : '参加を取り消しました')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    // 参加中なら赤、未参加なら白（標準）
                                    backgroundColor: isPresent ? Colors.red.shade600 : null,
                                    foregroundColor: isPresent ? Colors.white : null,
                                  ),
                                  icon: Icon(isPresent ? Icons.check_circle : Icons.check_circle_outline),
                                  label: Text(isPresent ? '参加中' : '参加する'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.group),
                                  label: const Text('出席状況を見る'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('オーダーシートを見る'),
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
              const SizedBox(height: 24),
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
                  Text('公式レート : ${player.rating.toStringAsFixed(2)}'),
                  if (player.isProvisional)
                    const Text(
                      '※手入力の仮レート適用中',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('成績スタッツ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('01 : ${player.effectiveStats01.toStringAsFixed(2)}'),
                Text('クリケット : ${player.effectiveStatsCricket.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('勝敗 : ${player.wins}勝 ${player.losses}敗'),
                Text('勝率 : ${(player.winRate * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}