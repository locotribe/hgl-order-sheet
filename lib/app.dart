import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/mypage_screen.dart';
import 'screens/name_entry_screen.dart';
import 'services/app_state.dart';

class HglOrderSheetApp extends StatelessWidget {
  const HglOrderSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'HGL オーダーシート',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const RootGate(),
      ),
    );
  }
}

/// LIFF初期化・本人紐付け状態に応じて画面を出し分けるゲート。
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (appState.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('エラーが発生しました:\n${appState.errorMessage}'),
          ),
        ),
      );
    }
    if (!appState.isRegistered) {
      return const NameEntryScreen();
    }
    return const MyPageScreen();
  }
}
