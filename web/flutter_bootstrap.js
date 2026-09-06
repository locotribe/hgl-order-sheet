{{flutter_js}}
{{flutter_build_config}}

// Service Worker（PWAキャッシュ）を意図的に無効化している。
// デフォルトのFlutter Service Workerは「タブを全部閉じるまで新バージョンが
// 反映されない」というライフサイクルの都合上、通常のリロードでは更新が
// 反映されず、ユーザーごとにキャッシュクリアが必要になってしまうため。
// serviceWorkerSettings を渡さずに load() することで登録自体をスキップする。
_flutter.loader.load();
