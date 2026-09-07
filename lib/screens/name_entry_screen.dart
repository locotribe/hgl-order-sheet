// [修正] アプリバーに管理者画面への隠し導線（5回タップ）を追加 (v1.9.6)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'admin_gate_screen.dart';

/// 初回のみ：漢字フルネームを入力してLINEユーザーIDと紐付ける（SPEC.md §4 画面1）。
class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key});

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  int _adminTapCount = 0;
  Timer? _adminTapTimer;

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AppState>().registerName(_nameController.text.trim());
    } catch (e) {
      setState(() => _error = '登録に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleAdminTap,
          child: const Text('ハイブグローバルリーグ'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '初回登録',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('お名前（漢字フルネーム）を入力してください。\n※氏名は、リーグの成績ページと同じ表記で入力してください（苗字と名前の間に全角スペースを入れる）。例：今北 俺'),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '氏名',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '氏名を入力してください';
                      }

                      // 1. 苗字と名前の間に全角スペースが含まれているかチェック
                      if (!value.contains('\u3000')) {
                        return '苗字と名前の間には全角スペースを入れてください（例：今北 俺）';
                      }

                      // 2. 半角スペースが含まれていないかチェック（念のため）
                      if (value.contains(' ')) {
                        return '半角スペースではなく全角スペースを使用してください';
                      }

                      // 3. 全角文字（漢字、ひらがな、カタカナ、全角スペース）以外の文字（半角英数・記号等）が含まれていないかチェック
                      final invalidCharRegex = RegExp(r'[^\u3000-\u9FAF\u3040-\u309F\u30A0-\u30FF]');
                      if (invalidCharRegex.hasMatch(value)) {
                        return '漢字、ひらがな、カタカナ、および全角スペースのみで入力してください';
                      }

                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('登録する'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}