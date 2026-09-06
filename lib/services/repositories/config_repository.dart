import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_config.dart';
import '../../utils/password_hash.dart';

class ConfigRepository {
  ConfigRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('config').doc('app');

  Future<AppConfig> get() async {
    final snap = await _doc.get();
    return AppConfig.fromMap(snap.data());
  }

  Stream<AppConfig> watch() {
    return _doc.snapshots().map((snap) => AppConfig.fromMap(snap.data()));
  }

  /// 初回のみ：管理者パスワードを設定する（`config/app` が未作成の場合）。
  Future<void> setInitialPassword(String password) async {
    final hashed = PasswordHasher.hashNewPassword(password);
    await _doc.set(
      AppConfig(
        adminPasswordHash: hashed.hash,
        adminPasswordSalt: hashed.salt,
      ).toMap(),
    );
  }

  Future<void> changePassword(String newPassword) => setInitialPassword(newPassword);

  Future<bool> verifyPassword(String password) async {
    final config = await get();
    if (!config.isPasswordSet) return false;
    return PasswordHasher.verify(
      password: password,
      hash: config.adminPasswordHash!,
      salt: config.adminPasswordSalt!,
    );
  }
}
