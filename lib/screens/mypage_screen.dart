// [修正] UIの並び順変更と整理、成績スタッツ専用ページへの入り口を追加 (v1.9.6)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'performance_stats_screen.dart';
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
  final _gameRepository = GameRepository();

  int _adminTapCount = 0;
  Timer? _adminTapTimer;

  @override
  void dispose() {
    _adminTapTimer?.cancel();
    super.dispose();
  }

  void _handleAdminTap() {
    _adminTapTimer?.cancel();
    _adminTapCount++;

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminGateScreen()),
      );
    } else {
      _adminTapTimer = Timer(const Duration(seconds: 1), () {
        _adminTapCount = 0;
      });
    }
  }

  Future<void> _launchWeb(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchAppOrStore() async {
    final appUrl = Uri.parse('dlsports://');
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    try {
      if (kIsWeb) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(appUrl)) {
          await launchUrl(appUrl, mode: LaunchMode.externalApplication);
          return;
        }
        throw Exception('App not installed');
      }
    } catch (e) {
      if (isAndroid) {
        await _launchWeb('https://play.google.com/store/apps/details?id=com.dartslive.dlsports');
      } else if (isIOS) {
        await _launchWeb('https://apps.apple.com/jp/app/dartslive-sports/id1400105618');
      }
    }
  }

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

  Future<void> _handleAttendanceToggle({
    required Week week,
    required String myId,
    required bool isPresent,
  }) async {
    if (isPresent) {
      final games = await _gameRepository.getAllOnce(week.id);
      if (games.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('既にオーダーが生成されているため、不参加への変更は管理者に依頼してください')),
          );
        }
        return;
      }

      await _attendanceRepository.setPresent(
        weekId: week.id,
        playerId: myId,
        present: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('参加を取り消しました')),
        );
      }
      return;
    }

    final times = ['20:50', '21:00', '21:10', '21:20', '21:30'];
    String? selectedTime;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('参加確認'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '試合開始十分前までに到着できない方は、下記の時刻を選んでください。それより前に来れる方は入力不要です。',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '到着予定時刻（任意）:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTime,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('指定しない（通常通り参加）'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('指定しない（通常通り参加）'),
                      ),
                      for (final t in times)
                        DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedTime = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('参加する'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await _attendanceRepository.setPresent(
      weekId: week.id,
      playerId: myId,
      present: true,
      arrivalTime: selectedTime,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('参加を記録しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myId = appState.currentPlayer!.id;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleAdminTap,
          child: const Text('マイページ'),
        ),
      ),
      body: StreamBuilder<Player?>(
        stream: _playerRepository.watchById(myId),
        initialData: appState.currentPlayer,
        builder: (context, playerSnap) {
          final player = playerSnap.data ?? appState.currentPlayer!;

          return StreamBuilder<Week?>(
            stream: _weekRepository.watchCurrentWeek(),
            builder: (context, weekSnap) {
              final week = weekSnap.data;

              return StreamBuilder<List<Attendance>>(
                stream: week != null ? _attendanceRepository.watchAll(week.id) : const Stream.empty(),
                builder: (context, attSnap) {
                  final attendanceList = attSnap.data ?? [];
                  final myAttendance = attendanceList.where((a) => a.playerId == myId).firstOrNull;
                  final isPresent = myAttendance?.present ?? false;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. 今週の試合カード または 情報なしメッセージ
                      if (week == null)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('今週の試合情報がありません'),
                          ),
                        )
                      else ...[
                        MatchInfoCard(week: week),
                        const SizedBox(height: 16),

                        // 2. 参加・出欠状況ボタン群
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _handleAttendanceToggle(
                                  week: week,
                                  myId: myId,
                                  isPresent: isPresent,
                                ),
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
                        const SizedBox(height: 16),

                        // 3. オーダーシートを見るボタン
                        OutlinedButton.icon(
                          icon: const Icon(Icons.list_alt),
                          label: const Text('オーダーシートを見る'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ResultSheetScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 4. 自分の名前変更＆スタッツ表示カード
                      _ProfileCard(
                        player: player,
                        onEditName: () => _editDisplayName(player),
                      ),
                      const SizedBox(height: 24),

                      // 5. 公式リンクとアプリ誘導
                      InkWell(
                        onTap: () => _launchWeb('https://dartshive.com/league/'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'ハイブグローバルリーグ公式ページ',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _launchAppOrStore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/image_f6d8df.png',
                                  width: 48,
                                  height: 48,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.sports_esports, size: 48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '※詳しいデータは専用アプリから確認してください。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              );
            },
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
        child: Column(
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, // ボタンを横幅いっぱいに広げる
              child: FilledButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('成績スタッツを見る'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PerformanceStatsScreen(),
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