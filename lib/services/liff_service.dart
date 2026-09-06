import 'dart:js_interop';

extension type _LiffBridge._(JSObject _) implements JSObject {
  external bool get loggedIn;
  external String? get userId;
  external String? get displayName;
  external String? get pictureUrl;
  external String? get errorMessage;
  external JSPromise<JSBoolean> init(JSString liffId);
}

@JS('liffBridge')
external _LiffBridge get _liffBridge;

class LiffProfile {
  const LiffProfile({required this.userId, this.displayName, this.pictureUrl});

  final String userId;
  final String? displayName;
  final String? pictureUrl;
}

class LiffException implements Exception {
  LiffException(this.message);
  final String message;

  @override
  String toString() => 'LiffException: $message';
}

/// web/index.html の liffBridge を dart:js_interop 経由で呼び出すラッパー。
class LiffService {
  /// LIFFを初期化し、ログイン中プロフィールを取得する。
  /// 未ログインの場合は liff.login() によって画面遷移するため、
  /// この呼び出しはその場合 null を返す（実質は戻ってこない）。
  Future<LiffProfile?> init(String liffId) async {
    final loggedIn = await _liffBridge.init(liffId.toJS).toDart;
    if (!loggedIn.toDart) {
      final error = _liffBridge.errorMessage;
      if (error != null) throw LiffException(error);
      return null;
    }
    final userId = _liffBridge.userId;
    if (userId == null) {
      throw LiffException('LIFF profile did not contain a userId.');
    }
    return LiffProfile(
      userId: userId,
      displayName: _liffBridge.displayName,
      pictureUrl: _liffBridge.pictureUrl,
    );
  }
}
