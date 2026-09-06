import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/game_definitions.dart';
import '../logic/assignment_engine.dart';
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
import 'admin_gate_screen.dart';
import 'result_sheet_screen.dart';

/// 画面2：出席確認 — SPEC.md §4
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _weekRepository = WeekRepository();
  final _playerRepository = PlayerRepository();
  final _attendanceRepository = AttendanceRepository();
  final _guestRepository = GuestRepository();
  final _gameRepository = GameRepository();
  final _engine = AssignmentEngine();
  bool _generating = false;

  Future<void> _generateOrder(
    Week week,
    List<Player> players,
    List<Attendance> attendance,
    List<Guest> guests,
  ) async {
    final presentIds = attendance
        .where((a) => a.present)
        .map((a) => a.playerId)
        .toSet();
    final presentPlayers = players.where((p) => presentIds.contains(p.id));

    final entrants = [
      ...presentPlayers.map(
        (p) => AssignmentEntrant(
          id: p.id,
          name: p.kanjiName,
          stats01: p.effectiveStats01,
          statsCricket: p.effectiveStatsCricket,
        ),
      ),
      ...guests.map(
        (g) => AssignmentEntrant(
          id: g.id,
          name: g.name,
          stats01: g.rating,
          statsCricket: g.rating,
        ),
      ),
    ];

    if (entrants.length < kMinAttendanceForValidMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3人以上の参加が必要です。')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final result = _engine.generate(
        entrants: entrants,
        homeAway: week.homeAway,
      );
      final slots = result.assignments.map((a) {
        final def = kGameDefinitions.firstWhere(
          (d) => d.number == a.gameNumber,
        );
        return GameSlot.fromDefinition(
          def,
        ).copyWith(assigned: a.assignedIds, firstThrow: a.firstThrow);
      }).toList();

      final myId = context.read<AppState>().currentPlayer!.id;
      await _gameRepository.saveAll(
        weekId: week.id,
        slots: slots,
        editedBy: myId,
      );

      if (!mounted) return;
      if (!result.feasible) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('一部、規定上限ぎりぎりの割り当てになりました。リザルトシートで確認してください。'),
          ),
        );
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ResultSheetScreen()));
    } on AssignmentException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出席確認')),
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
              return StreamBuilder<List<Attendance>>(
                stream: _attendanceRepository.watchAll(week.id),
                builder: (context, attendanceSnap) {
                  final attendance = attendanceSnap.data ?? [];
                  return StreamBuilder<List<Guest>>(
                    stream: _guestRepository.watchAll(week.id),
                    builder: (context, guestSnap) {
                      final guests = guestSnap.data ?? [];
                      final presentIds = attendance
                          .where((a) => a.present)
                          .map((a) => a.playerId)
                          .toSet();
                      final presentCount = presentIds.length + guests.length;
                      final isValid =
                          presentCount >= kMinAttendanceForValidMatch;

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('対戦相手: ${week.opponentTeam}'),
                                  Text(
                                    week.homeAway == HomeAway.home
                                        ? 'HOME'
                                        : 'AWAY',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            color: isValid
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                isValid
                                    ? '参加人数: $presentCount人（成立）'
                                    : '参加人数: $presentCount人（不成立：3人以上必要）',
                                style: TextStyle(
                                  color: isValid
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '参加者一覧',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          for (final p in players)
                            ListTile(
                              leading: Icon(
                                presentIds.contains(p.id)
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: presentIds.contains(p.id)
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              title: Text(p.kanjiName),
                              trailing: Text(p.rating.toStringAsFixed(1)),
                            ),
                          for (final g in guests)
                            ListTile(
                              tileColor: Colors.amber.withValues(alpha: 0.15),
                              leading: const Icon(
                                Icons.person_add,
                                color: Colors.amber,
                              ),
                              title: Text('${g.name}（ゲスト）'),
                              trailing: Text(g.rating.toStringAsFixed(1)),
                            ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lock),
                            label: const Text('ゲスト追加・メンバー管理（管理者）'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AdminGateScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            icon: _generating
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('オーダーを自動生成する'),
                            onPressed: _generating
                                ? null
                                : () => _generateOrder(
                                    week,
                                    players,
                                    attendance,
                                    guests,
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
      ),
    );
  }
}
