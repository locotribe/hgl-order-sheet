// [修正] 成績スタッツ専用ページ (v1.9.7)
// - ゲーム形式別 → type × format ごとに勝敗付きで表示
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/historical_stats_calculator.dart';
import '../models/player.dart';
import '../services/app_state.dart';
import '../services/repositories/player_repository.dart';

class PerformanceStatsScreen extends StatefulWidget {
  const PerformanceStatsScreen({super.key});

  @override
  State<PerformanceStatsScreen> createState() => _PerformanceStatsScreenState();
}

class _PerformanceStatsScreenState extends State<PerformanceStatsScreen> {
  final _playerRepository = PlayerRepository();
  final _calculator = HistoricalStatsCalculator();

  late Future<List<GameTypeStats>> _statsFuture;
  late String _myId;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AppState>().currentPlayer!.id;
    _statsFuture = _calculator.getPlayerGameTypeStats(_myId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成績スタッツ'),
      ),
      body: StreamBuilder<Player?>(
        stream: _playerRepository.watchById(_myId),
        initialData: context.read<AppState>().currentPlayer,
        builder: (context, playerSnap) {
          final player = playerSnap.data;
          if (player == null) {
            return const Center(child: Text('プレイヤー情報が見つかりません'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. リーグレーティング表示
              Card(
                elevation: 4,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Column(
                    children: [
                      const Text(
                        'リーグレーティング',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        player.rating.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (player.isProvisional)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '※手入力の仮レーティング適用中',
                            style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 01 / クリケット スタッツ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '個人スタッツ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            label: '01 GAME',
                            value: player.effectiveStats01.toStringAsFixed(2),
                          ),
                          _StatItem(
                            label: 'CRICKET',
                            value: player.effectiveStatsCricket.toStringAsFixed(2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 勝敗数 / 勝率
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '勝敗データ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            label: '勝敗数',
                            value: '${player.wins}勝 ${player.losses}敗',
                          ),
                          _StatItem(
                            label: '勝率',
                            value: '${(player.winRate * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. ゲーム別（type × format）出場回数 + 勝敗
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ゲーム別の累計出場回数と勝敗',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const Divider(),
                      FutureBuilder<List<GameTypeStats>>(
                        future: _statsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('集計エラー: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                            );
                          }

                          final stats = snapshot.data ?? [];
                          if (stats.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('まだ試合に出場したデータがありません', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }

                          return Column(
                            children: stats.map((s) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(
                                '${s.type} (${HistoricalStatsCalculator.formatLabel(s.format)})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${s.wins}勝 ${s.losses}敗',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              trailing: Text(
                                '${s.total} 回',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            )).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// スタッツの項目を縦に並べるためのヘルパーウィジェット
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
