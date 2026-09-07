// [修正] 同一ゲーム内で重複しているプレイヤーを選択不可にする excludedIds を追加 (v1.9.5)
import 'package:flutter/material.dart';

import '../config/game_definitions.dart';
import '../logic/roster_counts.dart';

class RosterEntrant {
  const RosterEntrant({
    required this.id,
    required this.name,
    required this.isGuest,
  });

  final String id;
  final String name;
  final bool isGuest;
}

/// 入れ替え候補ピッカー（SPEC.md §4 画面3）。
/// 候補は「残D2」のように残り出場回数を名前先頭に表示し、残0はグレーで選択不可にする。
Future<String?> showPlayerPickerSheet({
  required BuildContext context,
  required List<RosterEntrant> roster,
  required GameFormat format,
  required int cap,
  required RosterCounts counts,
  required String? currentOccupantId,
  Set<String> excludedIds = const {},
}) {
  final letter = formatShortLetter(format);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'メンバーを選択',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            for (final entrant in roster)
              Builder(
                builder: (context) {
                  final isCurrent = entrant.id == currentOccupantId;
                  final isExcluded = excludedIds.contains(entrant.id);
                  final used =
                      counts.countFor(format, entrant.id) - (isCurrent ? 1 : 0);
                  final remaining = cap - used;
                  final disabled = (remaining <= 0 && !isCurrent) || isExcluded;
                  final displayRemaining = remaining < 0 ? 0 : remaining;
                  return ListTile(
                    enabled: !disabled,
                    tileColor: entrant.isGuest
                        ? Colors.amber.withValues(alpha: 0.1)
                        : null,
                    leading: isCurrent
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    title: Text(
                      '残$letter$displayRemaining ${entrant.name}'
                          '${entrant.isGuest ? "（ゲスト）" : ""}',
                      style: TextStyle(color: disabled ? Colors.grey : null),
                    ),
                    onTap: disabled
                        ? null
                        : () => Navigator.of(context).pop(entrant.id),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}