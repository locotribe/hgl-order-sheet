const { Firestore } = require('@google-cloud/firestore');
const { normalizeName } = require('./parse');

/**
 * Workload Identity Federation（鍵レス）で認証する。
 *
 * firebase-admin は GOOGLE_APPLICATION_CREDENTIALS が external_account
 * （WIF）形式の場合に "Invalid contents in the credentials file" で失敗するため、
 * google-auth-library を直接使う @google-cloud/firestore に切り替えている。
 * こちらは external_account 形式を正しく解釈できる。
 * サービスアカウント鍵JSONは使わない・発行しない。
 */
function initFirestore() {
  return new Firestore({ projectId: 'hive-global-league' });
}

/**
 * weeks/{weekId} を upsert する。既存のゲーム編成(games)・出席(attendance)・
 * ゲスト(guests)サブコレクションには触れない（親ドキュメントのフィールドのみ merge）。
 */
async function upsertWeeks(db, scheduleRecords) {
  const batch = db.batch();
  for (const record of scheduleRecords) {
    const ref = db.collection('weeks').doc(record.weekId);
    batch.set(
      ref,
      {
        date: Firestore.Timestamp.fromDate(new Date(record.date)),
        opponentTeam: record.opponentTeam,
        homeAway: record.homeAway,
        status: record.status,
      },
      { merge: true },
    );
  }
  await batch.commit();
  return scheduleRecords.length;
}

/**
 * players を氏名（空白除去で正規化）突き合わせで更新する。
 * 一致するプレイヤーが見つからない場合は新規作成せず、警告として返す
 * （新規メンバーの登録・LINEユーザーIDとの紐付けはアプリ側の管理者操作に委ねる）。
 */
async function updatePlayers(db, memberRecords) {
  const snapshot = await db.collection('players').get();
  const players = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  const updated = [];
  const unmatched = [];

  const batch = db.batch();
  for (const record of memberRecords) {
    const match = players.find(
      (p) => normalizeName(p.kanjiName || '') === normalizeName(record.kanjiName),
    );
    if (!match) {
      unmatched.push(record.kanjiName);
      continue;
    }
    batch.update(db.collection('players').doc(match.id), {
      rating: record.rating,
      stats01: record.stats01,
      statsCricket: record.statsCricket,
      winRate: record.winRate,
      wins: record.wins,
      losses: record.losses,
      isProvisional: false,
    });
    updated.push(record.kanjiName);
  }
  await batch.commit();
  return { updated, unmatched };
}

module.exports = { initFirestore, upsertWeeks, updatePlayers };
