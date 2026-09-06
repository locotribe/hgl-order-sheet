// [修正] オーダー生成後は一般ユーザーの不参加変更をブロックする機能を追加 (v.1.5)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../models/player.dart';
import '../models/week.dart';
import '../services/app_state.dart';
import '../services/repositories/attendance_repository.dart';
import '../services/repositories/game_repository.dart';
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
  final _gameRepository = GameRepository(); // 追加

  Future<void> _editDisplayName(Player player) async {
    final controller = TextEditingController(text: player.effectiveName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('表示名の変更'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(labelText: '表示名'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
              ),
              const SizedBox(height: 12),
              const Text(
                '※表示される名前だけが変わります（成績の紐付けには影響しません）',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (newName == null || newName == player.effectiveName) return;

    final updatedPlayer = player.copyWith(
      displayName: newName,
    );

    await _playerRepository.update(updatedPlayer);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表示名を変更しました')),
      );
    }
  }

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
              _ProfileCard(
                player: player,
                onEditName: () => _editDisplayName(player),
              ),
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

                  return StreamBuilder<List<Attendance>>(
                    stream: _attendanceRepository.watchAll(week.id),
                    builder: (context, attSnap) {
                      final attendanceList = attSnap.data ?? [];
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
                                    // 不参加に変更しようとしている場合、オーダーが存在するかチェック
                                    if (isPresent) {
                                      final games = await _gameRepository.getAllOnce(week.id);
                                      if (games.isNotEmpty) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('既にオーダーが生成されているため、不参加への変更は管理者に依頼してください')),
                                          );
                                        }
                                        return;
                                      }
                                    }

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
                                  label: const Text('出席状況'),
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
  const _ProfileCard({required this.player, required this.onEditName});
  final Player player;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          player.effectiveName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: '表示名を変更',
                        onPressed: onEditName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('公式レーティング : ${player.rating.toStringAsFixed(2)}'),
                  if (player.isProvisional)
                    const Text(
                      '※手入力の仮レーティング適用中',
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