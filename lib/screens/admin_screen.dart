// [修正] 管理者機能（メンバーの出欠手動切り替え追加） (v.1.2)
import 'package:flutter/material.dart';
import '../models/guest.dart';
import '../models/player.dart';
import '../models/week.dart';
import '../models/attendance.dart';
import '../services/repositories/config_repository.dart';
import '../services/repositories/guest_repository.dart';
import '../services/repositories/player_repository.dart';
import '../services/repositories/week_repository.dart';
import '../services/repositories/attendance_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _playerRepository = PlayerRepository();
  final _guestRepository = GuestRepository();
  final _weekRepository = WeekRepository();
  final _configRepository = ConfigRepository();
  final _attendanceRepository = AttendanceRepository();

  Future<void> _editManualRating(Player player) async {
    final controller = TextEditingController(
      text: (player.manualRating ?? player.rating).toString(),
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${player.kanjiName} のレーティング手入力'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '仮レーティング'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'レーティングを入力してください';
              if (double.tryParse(v) == null) return '数値を正しく入力してください';
              return null;
            },
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
              final value = double.parse(controller.text);
              Navigator.of(context).pop(value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null) return;
    await _playerRepository.setManualRating(
      playerId: player.id,
      manualRating: result,
    );
  }

  Future<void> _addGuest(Week week) async {
    final nameController = TextEditingController();
    final ratingController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ゲスト追加'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名前'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
              ),
              TextFormField(
                controller: ratingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'レーティング'),
                validator: (v) {
                  if (v == null || double.tryParse(v) == null) return '正しい数値を入力してください';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _guestRepository.add(
      weekId: week.id,
      name: nameController.text.trim(),
      rating: double.parse(ratingController.text),
    );
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パスワード変更'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新しいパスワード'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (confirmed != true || controller.text.isEmpty) return;
    await _configRepository.changePassword(controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('パスワードを変更しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者メニュー')),
      body: StreamBuilder<Week?>(
        stream: _weekRepository.watchCurrentWeek(),
        builder: (context, weekSnap) {
          final week = weekSnap.data;

          return StreamBuilder<List<Player>>(
            stream: _playerRepository.watchAll(),
            builder: (context, playersSnap) {
              final players = playersSnap.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('本日の出欠・ゲスト管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (week == null)
                    const Text('今週の試合情報がありません')
                  else ...[
                    StreamBuilder<List<Attendance>>(
                      stream: _attendanceRepository.watchAll(week.id),
                      builder: (context, attSnap) {
                        final attendance = attSnap.data ?? [];
                        final presentIds = attendance.where((a) => a.present).map((a) => a.playerId).toSet();

                        return Card(
                          child: Column(
                            children: [
                              for (final p in players)
                                SwitchListTile(
                                  title: Text(p.effectiveName),
                                  subtitle: Text(
                                    presentIds.contains(p.id) ? '参加' : '未参加',
                                    style: TextStyle(color: presentIds.contains(p.id) ? Colors.green : Colors.grey),
                                  ),
                                  value: presentIds.contains(p.id),
                                  onChanged: (val) {
                                    _attendanceRepository.setPresent(
                                      weekId: week.id,
                                      playerId: p.id,
                                      present: val,
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('本日のゲストを追加'),
                      onPressed: () => _addGuest(week),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Guest>>(
                      stream: _guestRepository.watchAll(week.id),
                      builder: (context, guestSnap) {
                        final guests = guestSnap.data ?? [];
                        if (guests.isEmpty) return const SizedBox.shrink();
                        return Card(
                          child: Column(
                            children: [
                              for (final g in guests)
                                ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(g.name),
                                  subtitle: Text('レーティング: ${g.rating.toStringAsFixed(2)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _guestRepository.remove(weekId: week.id, guestId: g.id),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 32),
                  const Text('メンバー管理（仮レーティング設定）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
// [修正] メンバー管理画面のプレイヤー名表示に displayName の括弧書きを追加 (v.1.5)
                  Card(
                    child: Column(
                      children: [
                        for (final p in players)
                          ListTile(
                            title: Text(
                              (p.displayName != null && p.displayName!.trim().isNotEmpty && p.displayName != p.kanjiName)
                                  ? '${p.kanjiName} (${p.displayName})'
                                  : p.kanjiName,
                            ),
                            subtitle: Text(
                              p.isProvisional
                                  ? '仮レーティング: ${p.effectiveStats01.toStringAsFixed(2)}'
                                  : 'レーティング: ${p.rating.toStringAsFixed(2)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'レーティングを手入力',
                              onPressed: () => _editManualRating(p),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  const Text('システム管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.password),
                    label: const Text('管理者パスワードを変更'),
                    onPressed: _changePassword,
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }
}