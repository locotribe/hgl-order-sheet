// SPEC.md §7: 日程（試合スケジュール）を取得して weeks/{weekId} に投入・照合する。
// 実行: node scrapeSchedule.js  （GitHub Actions から呼ばれる想定）
const { launchBrowser, openTeamDetail, extractScheduleItems } = require('./src/browser');
const { parseScheduleItems } = require('./src/parse');
const { initFirestore, upsertWeeks } = require('./src/firestore');
const { OUR_TEAM_NAME } = require('./src/config');

async function main() {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await openTeamDetail(page);
    const rawItems = await extractScheduleItems(page);
    const scheduleRecords = parseScheduleItems(rawItems, OUR_TEAM_NAME);

    console.log(`取得した試合数: ${scheduleRecords.length}`);
    for (const r of scheduleRecords) {
      console.log(`  ${r.weekId} vs ${r.opponentTeam} (${r.homeAway}) [${r.status}]`);
    }

    const db = initFirestore();
    const count = await upsertWeeks(db, scheduleRecords);
    console.log(`weeks へ ${count} 件を反映しました。`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
