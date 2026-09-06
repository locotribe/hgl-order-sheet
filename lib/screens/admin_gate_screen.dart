import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../services/repositories/config_repository.dart';
import 'admin_screen.dart';

/// 🔒からの入り口。パスワード認証（config/app が未作成なら初期設定モード）。
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key});

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  final _configRepository = ConfigRepository();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final Future<AppConfig> _configFuture;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _configFuture = _configRepository.get();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isFirstSetup) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (isFirstSetup) {
        await _configRepository.setInitialPassword(_passwordController.text);
      } else {
        final ok = await _configRepository.verifyPassword(
          _passwordController.text,
        );
        if (!ok) {
          setState(() => _error = 'パスワードが違います');
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
    } catch (e) {
      setState(() => _error = '処理に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者')),
      body: FutureBuilder<AppConfig>(
        future: _configFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final isFirstSetup = !snap.data!.isPasswordSet;
          return Center(
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
                      Text(
                        isFirstSetup ? '管理者パスワードの初期設定' : '管理者ログイン',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isFirstSetup ? '新しいパスワード' : 'パスワード',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'パスワードを入力してください'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : () => _submit(isFirstSetup),
                        child: Text(isFirstSetup ? '設定する' : 'ログイン'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
