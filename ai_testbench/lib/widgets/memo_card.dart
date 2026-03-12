import 'package:flutter/material.dart';

/// Visual preview card for a chrono-extracted memo.
///
/// Expects the JSON map to follow the chrono_ai_flow schema:
///   intent, title, datetime_expression_original, datetime_expression_english
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final intent = (data['intent'] as String?) ?? 'note';
    final title = (data['title'] as String?) ?? '—';
    final dtOriginal = data['datetime_expression_original'] as String?;
    final dtEnglish = data['datetime_expression_english'] as String?;

    final (icon, color) = _intentStyle(intent);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          intent.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Datetime expressions ────────────────────────────────────
            if (dtOriginal != null || dtEnglish != null) ...[
              const Divider(height: 24),
              if (dtOriginal != null)
                _dateTimeRow(
                  context,
                  label: 'Original',
                  value: dtOriginal,
                  color: color,
                ),
              if (dtEnglish != null && dtEnglish != dtOriginal)
                _dateTimeRow(
                  context,
                  label: 'English',
                  value: dtEnglish,
                  color: color,
                ),
            ],

            if (dtOriginal == null && intent != 'note') ...[
              const Divider(height: 24),
              Text(
                'No time expression extracted.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _dateTimeRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 18, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _intentStyle(String intent) {
    return switch (intent.toLowerCase()) {
      'reminder' || 'task' || 'todo' => (Icons.checklist, Colors.amber),
      'event' || 'meeting' => (Icons.event, Colors.lightBlue),
      'note' || 'idea' => (Icons.sticky_note_2, Colors.green),
      _ => (Icons.notes, Colors.grey),
    };
  }
}
