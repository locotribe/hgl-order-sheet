const puppeteer = require('puppeteer');
const { ROUNDTABLE_URL, OUR_TEAM_NAME } = require('./config');

async function launchBrowser() {
  return puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
}

/**
 * リーグ表（roundtable）ページを開き、自チームの「チーム詳細」オーバーレイを開く。
 * DOM構造は 2026-09 時点で実ページを調査して確認したもの：
 *   .team-row .team-link （テキストがチーム名） → クリックでオーバーレイ表示
 */
async function openTeamDetail(page) {
  await page.goto(ROUNDTABLE_URL, { waitUntil: 'networkidle2' });
  await page.waitForSelector('.team-row .team-link');

  const clicked = await page.evaluate((teamName) => {
    const links = Array.from(document.querySelectorAll('.team-row .team-link'));
    const target = links.find((el) => el.textContent.trim() === teamName);
    if (!target) return false;
    target.click();
    return true;
  }, OUR_TEAM_NAME);

  if (!clicked) {
    throw new Error(`チーム "${OUR_TEAM_NAME}" のリンクが見つかりませんでした（リーグ表のDOM構造が変わった可能性があります）。`);
  }

  await page.waitForSelector('.matchCard, .teamMemberTable', { timeout: 15000 });
}

/** 「試合スケジュール」タブに切り替え、試合一覧を素のJSONで取得する。 */
async function extractScheduleItems(page) {
  await page.evaluate(() => {
    const tabs = Array.from(document.querySelectorAll('button, a, div'));
    const tab = tabs.find((el) => el.textContent.trim() === '試合スケジュール' && el.children.length === 0);
    if (tab) tab.click();
  });
  await page.waitForSelector('.ls-division_scheduleListitem');

  return page.evaluate(() => {
    // 日付ごとの <h3>（日付）+ <ul>（その日の試合一覧）が同じ<section>内で
    // 繰り返し並ぶ構造（h3とulはitem自身の祖先ではなく兄弟要素）なので、
    // h3ごとに次のulを対応付けてから中のitemを読む。
    const dateHeaders = document.querySelectorAll('.ls-division_h3');
    const result = [];
    dateHeaders.forEach((h3) => {
      const dateHeader = h3.textContent.trim();
      const list = h3.nextElementSibling;
      if (!list) return;
      const items = list.querySelectorAll('.ls-division_scheduleListitem');
      items.forEach((item) => {
        const teams = Array.from(item.querySelectorAll('.ls-team')).map((t) => ({
          name: t.querySelector('.teamName')?.textContent.trim() || '',
          position: t.querySelector('.position')?.textContent.trim() || '',
        }));
        result.push({ itemCls: item.className, dateHeader, teams });
      });
    });
    return result;
  });
}

/** 「メンバーリスト」タブに切り替え、選手一覧を素のJSONで取得する。 */
async function extractMemberRows(page) {
  await page.evaluate(() => {
    const tabs = Array.from(document.querySelectorAll('button, a, div'));
    const tab = tabs.find((el) => el.textContent.trim() === 'メンバーリスト' && el.children.length === 0);
    if (tab) tab.click();
  });
  await page.waitForSelector('.teamMemberTable tbody tr.member');

  return page.evaluate(() => {
    const rows = document.querySelectorAll('.teamMemberTable tbody tr.member');
    return Array.from(rows).map((row) => {
      const cells = row.children;
      return {
        name: cells[0]?.textContent.trim() || '',
        rating: cells[1]?.textContent.trim() || '0',
        stats01: cells[2]?.querySelector('.stats')?.textContent.trim() || '0',
        statsCricket: cells[3]?.querySelector('.stats')?.textContent.trim() || '0',
        wins: cells[4]?.textContent.trim() || '0',
        losses: cells[5]?.textContent.trim() || '0',
        winRate: (cells[6]?.textContent.trim() || '0%').replace('%', ''),
      };
    });
  });
}

module.exports = { launchBrowser, openTeamDetail, extractScheduleItems, extractMemberRows };
