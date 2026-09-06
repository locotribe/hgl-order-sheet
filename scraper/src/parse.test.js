const test = require('node:test');
const assert = require('node:assert/strict');
const { parseScheduleItems, parseMemberRows, normalizeName, toWeekId } = require('./parse');

test('toWeekId converts slash-separated date to a Firestore-safe doc id', () => {
  assert.equal(toWeekId('2026/08/31'), '2026-08-31');
});

test('parseScheduleItems: 自チームの position を見て HOME/AWAY を判定する（店名「HOME」に惑わされない）', () => {
  const rawItems = [
    {
      itemCls: 'ls-division_scheduleListitem overlay-openBtn  --finish',
      dateHeader: '2026/08/31',
      teams: [
        { name: 'LOCO TRIBE', position: 'HOME' },
        { name: 'Eddie Nishinomiya【3】', position: 'AWAY' },
      ],
    },
    {
      // 相手チームの店舗名が「HOME」というトラップケース（SPEC.md §7）
      itemCls: 'ls-division_scheduleListitem overlay-openBtn  ',
      dateHeader: '2026/09/07',
      teams: [
        { name: 'HOME', position: 'HOME' },
        { name: 'LOCO TRIBE', position: 'AWAY' },
      ],
    },
  ];

  const result = parseScheduleItems(rawItems, 'LOCO TRIBE');

  assert.equal(result.length, 2);
  assert.deepEqual(result[0], {
    weekId: '2026-08-31',
    date: '2026/08/31',
    opponentTeam: 'Eddie Nishinomiya【3】',
    homeAway: 'home',
    status: 'completed',
  });
  assert.deepEqual(result[1], {
    weekId: '2026-09-07',
    date: '2026/09/07',
    opponentTeam: 'HOME',
    homeAway: 'away',
    status: 'scheduled',
  });
});

test('parseMemberRows: 実ページと同じ形式の文字列を数値に変換する', () => {
  const rawRows = [
    {
      name: '松田　涼',
      rating: '15.09',
      stats01: '105.44',
      statsCricket: '4.34',
      wins: '2',
      losses: '2',
      winRate: '50',
    },
  ];

  const result = parseMemberRows(rawRows);

  assert.equal(result.length, 1);
  assert.equal(result[0].kanjiName, '松田 涼');
  assert.equal(result[0].rating, 15.09);
  assert.equal(result[0].stats01, 105.44);
  assert.equal(result[0].statsCricket, 4.34);
  assert.equal(result[0].wins, 2);
  assert.equal(result[0].losses, 2);
  assert.equal(result[0].winRate, 0.5);
});

test('normalizeName: 全角/半角スペースの有無を吸収する', () => {
  assert.equal(normalizeName('松田　涼'), normalizeName('松田涼'));
  assert.equal(normalizeName('山田 太郎'), normalizeName('山田太郎'));
});
