/// config/app — SPEC.md §6
/// 管理者パスワードはハッシュ化して保存する（平文は一切保存しない）。
class AppConfig {
  const AppConfig({this.adminPasswordHash, this.adminPasswordSalt});

  final String? adminPasswordHash;
  final String? adminPasswordSalt;

  bool get isPasswordSet => adminPasswordHash != null && adminPasswordSalt != null;

  factory AppConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppConfig();
    return AppConfig(
      adminPasswordHash: map['adminPasswordHash'] as String?,
      adminPasswordSalt: map['adminPasswordSalt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminPasswordHash': adminPasswordHash,
      'adminPasswordSalt': adminPasswordSalt,
    };
  }
}
