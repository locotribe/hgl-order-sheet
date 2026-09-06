# HGLオーダーシート入力 — 実装仕様書 (SPEC)

LINEミニアプリ（LIFF）+ Flutter Web + Firebase で作る、ダーツリーグ「ハイブグローバルリーグ 2026 One80 Stage」の
チーム LOCO TRIBE 用オーダーシート管理アプリ。**手書きの印刷オーダーシートをアプリに置き換える**のが目的。

---

## 0. このドキュメントの使い方（Android Studio Claude Code CLI 向け）
- このファイルは仕様の唯一の情報源。実装時はここに従うこと。
- ファイル参照は**絶対パス**で指定する（例：`/Users/xxx/hgl_order_sheet/lib/...`）。
- **秘密情報（Firebase設定・パスワード等）はコミットしない**こと。`firebase_options.dart`・`.env`・`lib/config/secrets.dart` などは `.gitignore` に追加する。
- まず「§8 実装ステップ」の順で骨組みを作り、各画面・ロジックを §4〜§7 に沿って実装する。

---

## 1. 技術構成
- **クライアント**：Flutter（Web ターゲット）を LINEミニアプリ（LIFF）として動作させる。
- **LIFF**：`flutter_web` を LIFF でラップ。LIFF SDK は index.html に読み込み、`dart:js`/`package:js` 連携、または `flutter_inappwebview`/JS interop でユーザーID・プロフィールを取得。
  - **LIFF ID**：`2011463389-dkHQNpkC`
  - LIFFエンドポイントURL は Firebase Hosting デプロイ後のURLを LINE Developers 側に設定する。
- **DB**：Cloud Firestore（プロジェクトは作成済み）。クライアントから読み書き。
- **スクレイパー**：Firebase Cloud Functions（Node）。§7 参照。
- **ホスティング**：Firebase Hosting。

### Firebase 設定（値は各自で埋める・コミット禁止）
```
// lib/config/firebase_options.dart は flutterfire configure で生成する想定
// もしくは web/index.html に firebaseConfig を直接記述
const firebaseConfig = {
  apiKey: "★Firebaseコンソールのconfigから★",
  authDomain: "hive-global-league.firebaseapp.com",
  projectId: "hive-global-league",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
};
```

---

## 2. 登場人物と権限
- **参加者（一般）**：自分の参加ボタン、自分の成績閲覧、リザルトシートの閲覧・入れ替え・勝敗入力。
- **管理者**：上記に加え、パスワード保護の管理者画面で「ゲスト追加」「新規メンバーのレート手入力」「メンバー管理」。
- 認証は LINEユーザーID（LIFF）で本人識別。管理者判定はパスワード＋管理者フラグ。

---

## 3. リーグ規定（自動編成が守るルール）

### 全11ゲーム構成
| # | ゲーム | 形式(人数) | ハンデ | 強さ軸 |
|---|--------|-----------|--------|--------|
| 1 | 901 | トリオス(3) | オートハンデ | 01 |
| 2 | 701 | ダブルス(2) | オートハンデ | 01 |
| 3 | SHOOT OUT | ダブルス(2) | なし | 01 |
| 4 | 701 | ダブルス(2) | オートハンデ | 01 |
| 5 | S.CRICKET | シングルス(1) | オートハンデ | クリケット |
| 6 | HALF-IT | ダブルス(2) | なし | クリケット |
| 7 | S.CRICKET | トリオス(3) | オートハンデ | クリケット |
| 8 | 701 | シングルス(1) | オートハンデ | 01 |
| 9 | S.CRICKET | ダブルス(2) | オートハンデ | クリケット |
| 10 | 701 | ダブルス(2) | オートハンデ | 01 |
| 11 | 901 | トリオス(3) | オートハンデ | 01 |

### 出場回数の上限（1人あたり）
- シングルス：**1回**（対象 ⑤⑧）
- ダブルス：**4回**（対象 ②③④⑥⑨⑩、全6試合）
- トリオス：**3回**（対象 ①⑦⑪）
- 同じペアでのダブルスは **2回まで**。
- 最低3人で全11ゲーム成立（3人時：ダブルスは A&B・A&C・B&C を各2試合）。

### 先攻後攻
- 第1ゲーム：**HOMEチームが先攻**（自チームのHOME/AWAYは日程データから判定）。
- 第2ゲーム以降：**前ゲームで負けた方が先攻**（＝○×入力で次ゲームの先攻後攻が確定）。

---

## 4. 画面仕様（4画面）

### 画面1：個人トップ（マイページ）
- 初回のみ：漢字フルネームを本人が入力し、LINEユーザーIDと紐付け（players に保存）。
- 表示：氏名、レーティング、01スタッツ、クリケットスタッツ、リーグ成績（勝敗・勝率・チーム内順位）。
- 今週の試合カード（対戦相手・HOME/AWAY・日時）＋「参加する」ボタン。
- 「リザルトシートを見る」導線、「🔒 管理者メニュー」導線。

### 画面2：出席確認
- 今週の試合情報（対戦相手・HOME/AWAY）。
- 参加状況：参加人数と成立判定（3名以上で成立、2名以下は赤表示）。
- 参加者リスト（✓/未回答、レート表示）、ゲストは色分け。
- 「🔒 ゲスト追加・メンバー管理（管理者）」導線、「オーダーを自動生成する」ボタン。

### 画面3：リザルトシート（中心画面）
- 11ゲームを縦リスト表示。各行：ゲーム番号・名称・形式/ハンデタグ・先攻後攻タグ・割当メンバー・○×ボタン。
- **入れ替えUI**：名前セルをタップ → 候補ピッカー表示。候補は**名前先頭に残り出場回数**（例「残D2」）。残0はグレーで選択不可。
- **○×入力**：勝敗を記録（手書き置換）。入力すると次ゲームの先攻後攻が確定。
- **制約チェック（R1）**：出場回数上限を破る入れ替えは**保存させず、理由を表示**（例「田中さんはシングルス既に1回のため追加できません」）。
- 現在スコア表示。全員が同じシートを編集可能（Firestore で共有）。

### 画面4：管理者画面（パスワード保護）
- トップの🔒から入り、パスワード認証。
- メンバー管理：一覧＋レート表示。**新規メンバー（試合数なしでスクレイプ不可）はレートを手入力**（実データが出たら自動置換）。
- ゲスト追加：名前＋**レート必須**入力。**その日限り**（登録は残さない）。
- パスワード変更。

---

## 5. オーダー自動編成ロジック（検証済み）

### 方針
- 自動生成は**バランス重視の「たたき台」**。勝率最大化ではなく、全11ゲームに偏りなく配置することを最優先。生成後は**プレイヤーが自由に入れ替え**て仕上げる。
- **強さは2軸**：01系ゲームは各選手の01スタッツ、クリケット系はクリケットスタッツで測る。ハンデなしは SHOOT OUT=01・HALF-IT=クリケット。
- **相手チームのレートは使わない**（各ゲームの相手オーダーが試合開始まで不明なため割り切る）。
- 01系のオートハンデ：**先攻なら少し強め、後攻なら少し弱め**に傾ける。強さは「合計」を基本に、残り人数で最大・平均も併用。
- 新規メンバー／ゲストは単一の手入力レートを、01・クリケット両軸の代用値として使う。

### アルゴリズム（グリーディ＋バランス）
ゲーム①→⑪の順に、各ゲームで：
1. その形式の出場上限に余裕がある候補者を抽出。
2. スコア = `-（総出場数）×大きな重み + 強さ寄与`。総出場数が少ない人を最優先（バランス）。
3. ハンデなし・クリケットは強さ（該当軸スタッツ）を加点。01系は先攻/後攻の傾き（先攻+/後攻-、第1ゲームのみHOME/AWAYで既知、以降は中立）。
4. ダブルスはペア上限（同ペア2回）を満たす最良ペアを選ぶ。
- 埋まらない場合の再試行（フォールバック）を用意。3人ケースを必ず満たすこと。
- **検証済み**：3〜6人×先攻/後攻×ランダム24,000ケースで全ケース規定違反ゼロ。3人ケースはリーグ規定の解（A&B・A&C・B&C各2＋全トリオス）と一致。
- 参考実装（Python）：`/root/verify_assign.py` のロジックを Dart に移植する。

---

## 6. Firestore データモデル
```
players/{playerId}                      // 登録メンバー
  lineUserId, kanjiName, rating,
  stats01, statsCricket,                // 2軸の強さ（自動取得）
  manualRating, isProvisional,          // 試合数なし→手入力・実データで置換
  winLossByGame, winRate, isAdmin

weeks/{weekId}                          // 日程=初回に一括投入、HP照合で検証
  date, opponentTeam, homeAway, status

  weeks/{weekId}/attendance/{playerId}
    present, joinedAt

  weeks/{weekId}/guests/{guestId}
    name, rating                        // その日限り

  weeks/{weekId}/games/{1..11}
    type, format, handicap, rounds, credits,
    firstThrow(先攻/後攻), assigned[playerId],
    result(○/×), lastEditedBy, editedAt

scrapes/{timestamp}
  source, rawSnapshot, parsedAt

config/app
  adminPasswordHash                     // 管理者パスワード（ハッシュ保存）
```
- Firestore セキュリティルール：本番前に「LINEログイン済み本人のみ書き込み可」等に絞る（開発中はテストモード）。

---

## 7. スクレイピング仕様（GitHub Actions・無料）
**実行環境は Firebase Cloud Functions ではなく GitHub Actions を使う**（Blaze不要・無料）。

### 構成
- リポジトリ内 `/scraper` に**実行環境非依存の Node スクリプト**を置く（`puppeteer` + `firebase-admin`）。
- コア処理（ページ取得→パース→整形）は純関数に分離し、GitHub Actions からも将来Cloud Functionsからも呼べるようにする。
- Firestore への書き込みは **firebase-admin** で行う。認証は **Workload Identity Federation（鍵レス）**：
  `google-github-actions/auth@v2` で一時的な認証情報を取得し、`admin.credential.applicationDefault()` で初期化する。
  サービスアカウント鍵JSONは発行・保存・コミットしない。

### 対象データ
- チーム詳細メンバーリストが**主データ源**（名前・レーティング・各ゲームのスタッツ・勝敗・勝率）。**動的読み込み**のため Puppeteer で描画してから読む（または裏のAPIを叩く）。
- スクレイプ対象URL：
  - 日程（全試合）：`https://league.dartslive.com/jp/division?li=3efb6fd88f7575b8&di=08bb1d538cddd1c2&co=a75dec9087afa115&showAllSchedule=true`
  - ランキング（選手一覧・01/クリケットアベレージ・勝敗・勝率）：`https://league.dartslive.com/jp/ranking?li=3efb6fd88f7575b8&di=08bb1d538cddd1c2&co=a75dec9087afa115`
  - 星取表：`https://league.dartslive.com/jp/roundtable?li=3efb6fd88f7575b8&di=08bb1d538cddd1c2&co=a75dec9087afa115`

### 実行タイミング（`.github/workflows/scrape.yml`）
- **日程**：`?showAllSchedule=true` に全試合が載っているので**初回に1回取得して weeks に投入**。以降はHPと照合して差分（日程変更）を検知するのみ。
- **成績・レート**：GitHub Actions の **cron スケジュール**で取得（cronはUTC。日本時間へ換算する）。
  - 日程照合：毎週月曜 12:00 JST（= `0 3 * * 1` UTC）
  - 成績取得：毎週月曜 23:30 JST 頃（= `30 14 * * 1` UTC）※試合21:00開始→終了後を狙う
- **手動実行**：`workflow_dispatch` を有効にし、日程変更・順延などイレギュラー時に管理者が手動でスクレイプを回せるようにする。
- （将来オプション）アプリ側で全結果入力完了時に GitHub の `repository_dispatch` を叩けばイベント駆動にもできるが、トークン管理が必要なので初期はスケジュール＋手動で十分。

### 注意（重要）
- Hブロックに**チーム名が「HOME」の店舗**がある。HOME/AWAY判定を店名「HOME」と取り違えないよう、パースで明確に区別する。
- GitHub Actions の cron は数分遅延することがある。時刻はあくまで目安。

---

## 8. 実装ステップ（推奨順）
1. Flutter Web プロジェクト初期化（Web有効）、Firebase 連携（flutterfire configure、firestore/hosting 有効化）。
2. LIFF 初期化（index.html に LIFF SDK、LIFF ID `2011463389-dkHQNpkC`）。ユーザーID取得 → players 紐付け（初回氏名入力）。
3. データモデル（§6）を Firestore に用意。ゲーム定義（§3表）を定数化。
4. 画面1・2・3・4（§4）を実装。状態は Firestore 購読で共有。
5. 自動編成ロジック（§5）を Dart 実装＋制約チェック（R1）。
6. スクレイパー（§7）を `/scraper` に Node スクリプトで実装＋ `.github/workflows/scrape.yml`（cron＋workflow_dispatch）。まず日程一括投入、次に成績取得。認証は Workload Identity Federation（鍵レス）。
7. Firebase Hosting へデプロイ → 得たURLを LINE Developers の LIFFエンドポイントに設定。
8. Firestore セキュリティルールを本番用に。管理者パスワードをハッシュで設定。

---

## 参考ドキュメント
- 設計まとめ（HTML, 図解あり）：Artifact 参照。
- 編成アルゴリズム検証コード：`verify_assign.py`。
