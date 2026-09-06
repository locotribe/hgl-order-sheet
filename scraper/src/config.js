// SPEC.md §7 の対象URL・チーム名。
const LEAGUE_PARAMS = {
  li: '3efb6fd88f7575b8',
  di: '08bb1d538cddd1c2',
  co: 'a75dec9087afa115',
};

const OUR_TEAM_NAME = 'LOCO TRIBE';

function buildUrl(path) {
  const params = new URLSearchParams(LEAGUE_PARAMS).toString();
  return `https://league.dartslive.com/jp/${path}?${params}`;
}

const ROUNDTABLE_URL = buildUrl('roundtable');

module.exports = { LEAGUE_PARAMS, OUR_TEAM_NAME, ROUNDTABLE_URL, buildUrl };
