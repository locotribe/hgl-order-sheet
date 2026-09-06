import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/week.dart';
import '../services/repositories/config_repository.dart';
import '../services/repositories/guest_repository.dart';
import '../services/repositories/player_repository.dart';
import '../services/repositories/week_repository.dart';

/// 画面4：管理者画面 — SPEC.md §4
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

  Future<void> _editManualRating(Player player) async {
    final controller = TextEditingController(
      text: (player.manualRating ?? player.rating).toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${player.kanjiName} のレート手入力'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'レート'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
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
        title: const Text('ゲスト追加（その日限り）'),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'レート（必須）'),
                validator: (v) {
                  if (v == null || double.tryParse(v) == null) {
                    return 'レートを数値で入力してください';
                  }
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
            child: const Text('変更する'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.isEmpty) return;
    await _configRepository.changePassword(controller.text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードを変更しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者画面')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('メンバー管理', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<Player>>(
            stream: _playerRepository.watchAll(),
            builder: (context, snap) {
              final players = snap.data ?? [];
              return Column(
                children: [
                  for (final p in players)
                    ListTile(
                      title: Text(p.kanjiName),
                      subtitle: Text(
                        p.isProvisional
                            ? '暫定レート: ${p.effectiveStats01.toStringAsFixed(2)}'
                            : 'レート: ${p.rating.toStringAsFixed(2)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'レート手入力',
                        onPressed: () => _editManualRating(p),
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          const Text('ゲスト追加', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<Week?>(
            stream: _weekRepository.watchCurrentWeek(),
            builder: (context, snap) {
              final week = snap.data;
              if (week == null) {
                return const Text('今週の試合予定がまだ登録されていません。');
              }
              return FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('今週のゲストを追加'),
                onPressed: () => _addGuest(week),
              );
            },
          ),
          const Divider(height: 32),
          const Text('パスワード変更', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.password),
            label: const Text('管理者パスワードを変更'),
            onPressed: _changePassword,
          ),
        ],
      ),
    );
  }
}
