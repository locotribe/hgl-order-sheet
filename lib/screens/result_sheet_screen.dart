// [修正] リザルトシート上部に出場回数・合計試合数のサマリー一覧を追加 (v.1.4)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/game_definitions.dart';
import '../logic/roster_counts.dart';
import '../models/attendance.dart';
import '../models/game_slot.dart';
import '../models/guest.dart';
import '../models/player.dart';
import '../models/week.dart';
import '../services/app_state.dart';
import '../services/repositories/attendance_repository.dart';
import '../services/repositories/game_repository.dart';
import '../services/repositories/guest_repository.dart';
import '../services/repositories/player_repository.dart';
import '../services/repositories/week_repository.dart';
import '../widgets/player_picker_sheet.dart';

/// リザルトシート画面 SPEC.md対応
class ResultSheetScreen extends StatefulWidget {
  const ResultSheetScreen({super.key});

  @override
  State<ResultSheetScreen> createState() => _ResultSheetScreenState();
}

class _ResultSheetScreenState extends State<ResultSheetScreen> {
  final _weekRepository = WeekRepository();
  final _playerRepository = PlayerRepository();
  final _attendanceRepository = AttendanceRepository();
  final _guestRepository = GuestRepository();
  final _gameRepository = GameRepository();

  void _showReasonDialog(String reason) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('追加できません'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _onTapSlot({
    required Week week,
    required GameSlot game,
    required int slotIndex,
    required List<GameSlot> allGames,
    required List<RosterEntrant> roster,
    required Map<String, String> idToName,
  }) async {
    final def = kGameDefinitions.firstWhere((d) => d.number == game.number);
    final counts = RosterCounts.compute(allGames);
    final currentOccupant = game.assigned.length > slotIndex
        ? game.assigned[slotIndex]
        : null;

    final selected = await showPlayerPickerSheet(
      context: context,
      roster: roster,
      format: def.format,
      cap: def.perPlayerCap,
      counts: counts,
      currentOccupantId: currentOccupant,
    );

    if (selected == null || selected == currentOccupant) return;
    if (!mounted) return;

    final used =
        counts.countFor(def.format, selected) -
            (selected == currentOccupant ? 1 : 0);
    final remaining = def.perPlayerCap - used;

    if (remaining <= 0) {
      final name = idToName[selected] ?? selected;
      _showReasonDialog(
        '$name さんは ${formatLabel(def.format)} に既に ${def.perPlayerCap} 回出場しているため追加できません。',
      );
      return;
    }

    if (def.format == GameFormat.doubles) {
      final otherIndex = slotIndex == 0 ? 1 : 0;
      final other = game.assigned.length > otherIndex
          ? game.assigned[otherIndex]
          : null;
      if (other != null && other != selected) {
        final pairCountsExcl = RosterCounts.compute(
          allGames,
          excludeGameNumber: game.number,
        ).pairs;
        final key = RosterCounts.pairKey(selected, other);
        final newCount = (pairCountsExcl[key] ?? 0) + 1;
        if (newCount > kMaxSamePairDoubles) {
          final selectedName = idToName[selected] ?? selected;
          final otherName = idToName[other] ?? other;
          _showReasonDialog(
            '$selectedName さんと $otherName さんのペアは既に $kMaxSamePairDoubles 回組んでいるため追加できません。',
          );
          return;
        }
      }
    }

    final newAssigned = [...game.assigned];
    while (newAssigned.length <= slotIndex) {
      newAssigned.add('');
    }
    newAssigned[slotIndex] = selected;

    final myId = context.read<AppState>().currentPlayer!.id;
    await _gameRepository.saveAssignment(
      weekId: week.id,
      slot: game.copyWith(assigned: newAssigned),
      editedBy: myId,
    );
  }

  Future<void> _setResult({
    required Week week,
    required GameSlot game,
    required GameResult tapped,
    required List<GameSlot> allGames,
  }) async {
    final myId = context.read<AppState>().currentPlayer!.id;
    final newResult = game.result == tapped ? GameResult.pending : tapped;

    await _gameRepository.saveAssignment(
      weekId: week.id,
      slot: game.copyWith(result: newResult),
      editedBy: myId,
    );

    if (game.number >= 11) return;

    final nextGame = allGames.firstWhere((g) => g.number == game.number + 1);
    final nextFirstThrow = newResult == GameResult.pending
        ? FirstThrow.undecided
        : (newResult == GameResult.win
        ? FirstThrow.second
        : FirstThrow.first);

    await _gameRepository.saveAssignment(
      weekId: week.id,
      slot: nextGame.copyWith(firstThrow: nextFirstThrow),
      editedBy: myId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('リザルトシート')),
      body: StreamBuilder<Week?>(
        stream: _weekRepository.watchCurrentWeek(),
        builder: (context, weekSnap) {
          final week = weekSnap.data;
          if (weekSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (week == null) {
            return const Center(child: Text('今週の試合情報がありません'));
          }

          return StreamBuilder<List<Player>>(
            stream: _playerRepository.watchAll(),
            builder: (context, playersSnap) {
              final players = playersSnap.data ?? [];
              return StreamBuilder<List<Guest>>(
                stream: _guestRepository.watchAll(week.id),
                builder: (context, guestSnap) {
                  final guests = guestSnap.data ?? [];
                  return StreamBuilder<List<Attendance>>(
                    stream: _attendanceRepository.watchAll(week.id),
                    builder: (context, attendanceSnap) {
                      final attendance = attendanceSnap.data ?? [];

                      final presentIds = attendance
                          .where((a) => a.present)
                          .map((a) => a.playerId)
                          .toSet();

                      final roster = [
                        ...players
                            .where((p) => presentIds.contains(p.id))
                            .map(
                              (p) => RosterEntrant(
                            id: p.id,
                            name: p.effectiveName,
                            isGuest: false,
                          ),
                        ),
                        ...guests.map(
                              (g) => RosterEntrant(
                            id: g.id,
                            name: g.name,
                            isGuest: true,
                          ),
                        ),
                      ];

                      final idToName = <String, String>{
                        for (final p in players) p.id: p.kanjiName,
                        for (final g in guests) g.id: g.name,
                      };
                      final isGuestId = {for (final g in guests) g.id: true};

                      return StreamBuilder<List<GameSlot>>(
                        stream: _gameRepository.watchAll(week.id),
                        builder: (context, gamesSnap) {
                          final games = gamesSnap.data ?? [];
                          if (games.isEmpty) {
                            return const Center(
                              child: Text('ゲームデータがありません'),
                            );
                          }

                          final wins = games
                              .where((g) => g.result == GameResult.win)
                              .length;
                          final losses = games
                              .where((g) => g.result == GameResult.loss)
                              .length;

                          // 出場回数サマリーの計算
                          final counts = RosterCounts.compute(games);

                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  '現在のスコア : $wins 勝 $losses 敗',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 参加者の出場回数一覧サマリーカード
                              if (roster.isNotEmpty)
                                Card(
                                  margin: const EdgeInsets.all(8),
                                  child: ExpansionTile(
                                    title: const Text(
                                      '📊 出場回数サマリー（タップで展開）',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          children: [
                                            for (final entrant in roster)
                                              Builder(
                                                builder: (context) {
                                                  final sCount = counts.countFor(
                                                    GameFormat.singles,
                                                    entrant.id,
                                                  );
                                                  final dCount = counts.countFor(
                                                    GameFormat.doubles,
                                                    entrant.id,
                                                  );
                                                  final tCount = counts.countFor(
                                                    GameFormat.trios,
                                                    entrant.id,
                                                  );
                                                  final totalCount =
                                                      sCount + dCount + tCount;

                                                  const maxS = 1;
                                                  const maxD = 4;
                                                  const maxT = 3;

                                                  return Padding(
                                                    padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            entrant.isGuest
                                                                ? '${entrant.name} (G)'
                                                                : entrant.name,
                                                            style: TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                              color: entrant
                                                                  .isGuest
                                                                  ? Colors
                                                                  .amber
                                                                  .shade900
                                                                  : Colors
                                                                  .black87,
                                                            ),
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 4,
                                                          child: Text(
                                                            '合計: ${totalCount}試合',
                                                            style:
                                                            const TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 5,
                                                          child: Text(
                                                            'S:$sCount/$maxS  D:$dCount/$maxD  T:$tCount/$maxT',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: (sCount >=
                                                                  maxS ||
                                                                  dCount >=
                                                                      maxD ||
                                                                  tCount >=
                                                                      maxT)
                                                                  ? Colors
                                                                  .red
                                                                  .shade700
                                                                  : Colors
                                                                  .black54,
                                                            ),
                                                            textAlign:
                                                            TextAlign.end,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: games.length,
                                  itemBuilder: (context, index) {
                                    final game = games[index];
                                    final def = kGameDefinitions.firstWhere(
                                          (d) => d.number == game.number,
                                    );
                                    return _GameRow(
                                      game: game,
                                      def: def,
                                      idToName: idToName,
                                      isGuestId: isGuestId,
                                      onTapSlot: (slotIndex) => _onTapSlot(
                                        week: week,
                                        game: game,
                                        slotIndex: slotIndex,
                                        allGames: games,
                                        roster: roster,
                                        idToName: idToName,
                                      ),
                                      onTapResult: (result) => _setResult(
                                        week: week,
                                        game: game,
                                        tapped: result,
                                        allGames: games,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.def,
    required this.idToName,
    required this.isGuestId,
    required this.onTapSlot,
    required this.onTapResult,
  });

  final GameSlot game;
  final GameDefinition def;
  final Map<String, String> idToName;
  final Map<String, bool> isGuestId;
  final void Function(int slotIndex) onTapSlot;
  final void Function(GameResult result) onTapResult;

  String get _firstThrowLabel {
    switch (game.firstThrow) {
      case FirstThrow.first:
        return '先攻';
      case FirstThrow.second:
        return '後攻';
      case FirstThrow.undecided:
        return '未定';
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotCount = def.format.playerCount;
    final handicapLabel =
    def.handicap == HandicapType.auto ? 'オートハンデ' : 'ハンデなし';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. GAME Header (Dark Grey)
          Container(
            color: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(
              'GAME ${game.number}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          // 2. Sub Header (Light Blue)
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              '${game.type} (${formatLabel(def.format)} / $handicapLabel)',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          // 3. Body (First Throw + Players)
          Row(
            children: [
              // Left: 先攻 / 後攻
              SizedBox(
                width: 64,
                child: Center(
                  child: Text(
                    _firstThrowLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: game.firstThrow == FirstThrow.undecided
                          ? Colors.grey
                          : (game.firstThrow == FirstThrow.first
                          ? Colors.red.shade700
                          : Colors.blue.shade700),
                    ),
                  ),
                ),
              ),
              // Divider
              Container(width: 1, color: Colors.grey.shade300),
              // Center: プレイヤーリスト
              Expanded(
                child: Column(
                  children: List.generate(slotCount, (i) {
                    final id =
                    game.assigned.length > i ? game.assigned[i] : null;
                    final name = id == null || id.isEmpty
                        ? '（タップして追加）'
                        : (idToName[id] ?? '(不明)');
                    final isGuest = id != null && (isGuestId[id] ?? false);

                    return InkWell(
                      onTap: () => onTapSlot(i),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          border: i < slotCount - 1
                              ? Border(
                              bottom:
                              BorderSide(color: Colors.grey.shade200))
                              : null,
                          color: isGuest
                              ? Colors.amber.withValues(alpha: 0.1)
                              : null,
                        ),
                        child: Text(
                          isGuest ? '$name (ゲスト)' : name,
                          style: TextStyle(
                            fontSize: 16,
                            color: id == null || id.isEmpty ? Colors.grey : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1),
          // 4. Bottom: Win/Loss Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _ResultPanelButton(
                    label: '◯',
                    color: Colors.green,
                    selected: game.result == GameResult.win,
                    onTap: () => onTapResult(GameResult.win),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultPanelButton(
                    label: '✕',
                    color: Colors.red,
                    selected: game.result == GameResult.loss,
                    onTap: () => onTapResult(GameResult.loss),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanelButton extends StatelessWidget {
  const _ResultPanelButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade50,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: selected ? color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}