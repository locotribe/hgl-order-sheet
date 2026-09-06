import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHash {
  final String hash;
  final String salt;

  const PasswordHash({required this.hash, required this.salt});
}

/// 管理者パスワードの SHA-256 + salt ハッシュ化。平文は保存しない。
class PasswordHasher {
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hashWithSalt(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static PasswordHash hashNewPassword(String password) {
    final salt = _generateSalt();
    return PasswordHash(hash: _hashWithSalt(password, salt), salt: salt);
  }

  static bool verify({
    required String password,
    required String hash,
    required String salt,
  }) {
    return _hashWithSalt(password, salt) == hash;
  }
}
