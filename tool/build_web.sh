#!/usr/bin/env bash
# Flutter Webのリリースビルド。
#
# `flutter build web` は web/flutter_service_worker.js をそのままコピーせず、
# 独自の自己破壊型Service Workerを毎回再生成してしまう（内容はほぼ同等だが
# キャッシュの明示クリアを行わない）。このプロジェクトではキャッシュを
# 確実に空にしたいため、ビルド後に自前の web/flutter_service_worker.js で
# 上書きする。
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web --release

cp web/flutter_service_worker.js build/web/flutter_service_worker.js
echo "Copied web/flutter_service_worker.js -> build/web/flutter_service_worker.js"
