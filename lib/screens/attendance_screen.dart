// [修正] 出席確認ページの参加者一覧で変更された名前を単純に表示するよう修正 (v.1.3)
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
import '../widgets/match_info_card.dart';
import 'admin_gate_screen.dart';
import 'result_sheet_screen.dart';

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
    final validPresentIds = attendance
        .where((a) {
      if (!a.present) return false;
      if (a.arrivalTime != null && a.arrivalTime!.isNotEmpty) {
        return a.isArrived;
      }
      return true;
    })
        .map((a) => a.playerId)
        .toSet();

    final presentPlayers = players.where((p) => validPresentIds.contains(p.id));
    final entrants = [
      ...presentPlayers.map(
            (p) => AssignmentEntrant(
          id: p.id,
          name: p.effectiveName,
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
        const SnackBar(content: Text('条件を満たす有効な参加者が3名以上必要です（遅刻者は管理者の到着確認が必要です）')),
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
            content: Text('条件を満たす編成が見つからなかったため、ベストエフォートで生成しました。'),
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
            return const Center(child: Text('今週の試合情報がありません'));
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

                      final attendanceMap = {for (var a in attendance) a.playerId: a};

                      final presentIds = attendance
                          .where((a) => a.present)
                          .map((a) => a.playerId)
                          .toSet();
                      final presentCount = presentIds.length + guests.length;
                      final isValid =
                          presentCount >= kMinAttendanceForValidMatch;

                      final presentPlayers = players
                          .where((p) => presentIds.contains(p.id))
                          .toList();

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          MatchInfoCard(week: week),
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            color: isValid
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                isValid
                                    ? '参加人数: $presentCount人 （成立）'
                                    : '参加人数: $presentCount人 （不成立）',
                                style: TextStyle(
                                  color: isValid
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '参加者一覧',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          if (presentPlayers.isEmpty && guests.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('現在、参加しているメンバーはいません', style: TextStyle(color: Colors.grey)),
                            ),
                          for (final p in presentPlayers)
                            Builder(
                              builder: (context) {
                                final att = attendanceMap[p.id];
                                final arrivalTime = att?.arrivalTime;
                                final isArrived = att?.isArrived ?? false;

                                return ListTile(
                                  leading: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  title: Text(p.effectiveName),
                                  trailing: arrivalTime != null && arrivalTime.isNotEmpty
                                      ? Text(
                                    '到着予定: $arrivalTime${isArrived ? " (到着済)" : " (要確認)"}',
                                    style: TextStyle(
                                      color: isArrived ? Colors.green.shade700 : Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  )
                                      : null,
                                );
                              },
                            ),
                          for (final g in guests)
                            ListTile(
                              tileColor: Colors.amber.withValues(alpha: 0.1),
                              leading: const Icon(
                                Icons.person_add,
                                color: Colors.amber,
                              ),
                              title: Text('${g.name} (ゲスト)'),
                              trailing: Text('${g.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.black54)),
                            ),
                          const SizedBox(height: 32),
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
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: _generating
                                ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('オーダーを自動生成する', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _generating
                                ? null
                                : () => _generateOrder(
                              week,
                              players,
                              attendance,
                              guests,
                            ),
                          ),
                          const SizedBox(height: 24),
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