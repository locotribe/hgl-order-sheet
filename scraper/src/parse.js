// 実行環境（Puppeteer/ブラウザ）に依存しない純関数群。
// page.evaluate() が返す素のJSONを、Firestoreに書き込む形へ整形する。

/** "2026/08/31" -> "2026-08-31" */
function toWeekId(dateText) {
  return dateText.trim().replace(/\//g, '-');
}

/**
 * 試合スケジュール一覧（team detail overlay の「試合スケジュール」タブ由来）を
 * weeks/{weekId} 用のレコードに変換する。
 *
 * @param {{dateHeader: string, teams: {name: string, position: string}[], itemCls: string}[]} rawItems
 * @param {string} ourTeamName
 */
function parseScheduleItems(rawItems, ourTeamName) {
  return rawItems
    .map((item) => {
      const ourTeam = item.teams.find((t) => t.name === ourTeamName);
      const opponent = item.teams.find((t) => t.name !== ourTeamName);
      if (!ourTeam || !opponent) return null;
      return {
        weekId: toWeekId(item.dateHeader),
        date: item.dateHeader.trim(),
        opponentTeam: opponent.name,
        // 店舗名が「HOME」というチームがあっても、必ず自チーム自身の
        // .position（HOME/AWAY）を見て判定するため取り違えない（SPEC §7 注意）。
        homeAway: ourTeam.position === 'HOME' ? 'home' : 'away',
        status: item.itemCls.includes('--finish') ? 'completed' : 'scheduled',
      };
    })
    .filter(Boolean);
}

/**
 * チームメンバーリスト（team detail overlay の「メンバーリスト」タブ由来）を
 * players 更新用のレコードに変換する。
 *
 * @param {{name: string, rating: string, stats01: string, statsCricket: string, wins: string, losses: string, winRate: string}[]} rawRows
 */
function parseMemberRows(rawRows) {
  return rawRows.map((row) => ({
    kanjiName: row.name.trim().replace(/　/g, ' ').replace(/\s+/g, ' '),
    rating: Number.parseFloat(row.rating),
    stats01: Number.parseFloat(row.stats01),
    statsCricket: Number.parseFloat(row.statsCricket),
    wins: Number.parseInt(row.wins, 10) || 0,
    losses: Number.parseInt(row.losses, 10) || 0,
    winRate: Number.parseFloat(row.winRate) / 100,
  }));
}

/** 全角/半角スペースを除去した比較用の名前。表記ゆれ（"山田 太郎"/"山田太郎"）を吸収する。 */
function normalizeName(name) {
  return name.replace(/[\s　]+/g, '');
}

module.exports = { toWeekId, parseScheduleItems, parseMemberRows, normalizeName };
