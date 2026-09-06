import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/player.dart';
import 'liff_service.dart';
import 'repositories/player_repository.dart';

/// アプリ全体で共有する最小限の状態：現在のLINEユーザーIDと紐付け済みPlayer。
/// 各画面のデータ自体はFirestoreの Stream を直接購読する。
class AppState extends ChangeNotifier {
  AppState({PlayerRepository? playerRepository, LiffService? liffService})
    : _playerRepository = playerRepository ?? PlayerRepository(),
      _liffService = liffService ?? LiffService();

  final PlayerRepository _playerRepository;
  final LiffService _liffService;

  String? lineUserId;
  Player? currentPlayer;
  bool isLoading = true;
  String? errorMessage;

  bool get isRegistered => currentPlayer != null;

  /// LIFF初期化 → lineUserId取得 → 紐付け済みPlayer検索。
  /// kDebugMode かつ URLクエリ `?debug_uid=xxx` があればLIFFをバイパスする（本番ビルドでは無効）。
  Future<void> bootstrap() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final debugUid = kDebugMode
          ? Uri.base.queryParameters['debug_uid']
          : null;
      if (debugUid != null && debugUid.isNotEmpty) {
        lineUserId = debugUid;
      } else {
        final profile = await _liffService.init(kLiffId);
        if (profile == null) {
          // liff.login() へのリダイレクトが発生中のため、ここでは何もしない。
          return;
        }
        lineUserId = profile.userId;
      }
      currentPlayer = await _playerRepository.findByLineUserId(lineUserId!);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerName(String kanjiName) async {
    final id = await _playerRepository.createFromLiff(
      lineUserId: lineUserId!,
      kanjiName: kanjiName,
    );
    currentPlayer = await _playerRepository.getById(id);
    notifyListeners();
  }

  Future<void> refreshCurrentPlayer() async {
    if (lineUserId == null) return;
    currentPlayer = await _playerRepository.findByLineUserId(lineUserId!);
    notifyListeners();
  }
}
