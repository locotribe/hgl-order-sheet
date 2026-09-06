// [修正] 公式準拠の対戦カードUI（フッター削除） (v.1.1)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/week.dart';

class MatchInfoCard extends StatelessWidget {
  const MatchInfoCard({super.key, required this.week});

  final Week week;

  @override
  Widget build(BuildContext context) {
    final homeTeam = week.homeAway == HomeAway.home ? 'LOCO TRIBE' : week.opponentTeam;
    final awayTeam = week.homeAway == HomeAway.away ? 'LOCO TRIBE' : week.opponentTeam;

    final dateStr = DateFormat('yyyy/MM/dd').format(week.date);
    final timeStr = '21:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        homeTeam,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'HOME',
                        style: TextStyle(color: Colors.blue.shade200, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'REMOTE',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        awayTeam,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'AWAY',
                        style: TextStyle(color: Colors.blue.shade200, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}