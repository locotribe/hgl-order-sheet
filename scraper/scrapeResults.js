// SPEC.md §7: 成績・レートを取得して players を更新する。
// 実行: node scrapeResults.js （GitHub Actions から呼ばれる想定）
const { launchBrowser, openTeamDetail, extractMemberRows } = require('./src/browser');
const { parseMemberRows } = require('./src/parse');
const { initFirestore, updatePlayers } = require('./src/firestore');

async function main() {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await openTeamDetail(page);
    const rawRows = await extractMemberRows(page);
    const memberRecords = parseMemberRows(rawRows);

    console.log(`取得した選手数: ${memberRecords.length}`);
    for (const m of memberRecords) {
      console.log(`  ${m.kanjiName}: Rt=${m.rating} 01=${m.stats01} CRICKET=${m.statsCricket} 勝率=${m.winRate}`);
    }

    const db = initFirestore();
    const { updated, unmatched } = await updatePlayers(db, memberRecords);
    console.log(`players を ${updated.length} 件更新しました。`);
    if (unmatched.length > 0) {
      console.log(`未登録（players に見つからない）氏名: ${unmatched.join(', ')}`);
      console.log('→ 管理者画面から新規メンバーとして登録し、氏名を一致させてください。');
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
