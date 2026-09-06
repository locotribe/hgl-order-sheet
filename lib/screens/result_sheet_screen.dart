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

/// 画面3：リザルトシート（中心画面）— SPEC.md §4
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
        title: const Text('変更できません'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
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
        '$nameさんは${formatLabel(def.format)}既に${def.perPlayerCap}回のため追加できません',
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
            '$selectedNameさんと$otherNameさんは同ペアで既に$kMaxSamePairDoubles回組んでいるため、'
            'これ以上組み合わせられません',
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
            return const Center(child: Text('今週の試合予定はまだ登録されていません。'));
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
                                name: p.kanjiName,
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
                              child: Text('まだオーダーが生成されていません。出席確認画面から生成してください。'),
                            );
                          }
                          final wins = games
                              .where((g) => g.result == GameResult.win)
                              .length;
                          final losses = games
                              .where((g) => g.result == GameResult.loss)
                              .length;

                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  '現在のスコア: $wins勝 $losses敗',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text('${game.number}')),
                const SizedBox(width: 8),
                Text(
                  game.type,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(formatLabel(def.format)),
                  visualDensity: VisualDensity.compact,
                ),
                if (def.handicap == HandicapType.auto) ...[
                  const SizedBox(width: 4),
                  const Chip(
                    label: Text('オートハンデ'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const SizedBox(width: 4),
                Chip(
                  label: Text(_firstThrowLabel),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: game.firstThrow == FirstThrow.undecided
                      ? null
                      : Colors.blue.withValues(alpha: 0.15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(slotCount, (i) {
                final id = game.assigned.length > i ? game.assigned[i] : null;
                final name = id == null
                    ? '未定'
                    : (idToName[id] ?? '(不明)');
                final isGuest = id != null && (isGuestId[id] ?? false);
                return ActionChip(
                  label: Text(isGuest ? '$name（ゲスト）' : name),
                  backgroundColor: isGuest
                      ? Colors.amber.withValues(alpha: 0.15)
                      : null,
                  onPressed: () => onTapSlot(i),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ResultButton(
                  icon: Icons.circle_outlined,
                  selected: game.result == GameResult.win,
                  color: Colors.green,
                  onTap: () => onTapResult(GameResult.win),
                ),
                const SizedBox(width: 8),
                _ResultButton(
                  icon: Icons.close,
                  selected: game.result == GameResult.loss,
                  color: Colors.red,
                  onTap: () => onTapResult(GameResult.loss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color.withValues(alpha: 0.2) : null,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
