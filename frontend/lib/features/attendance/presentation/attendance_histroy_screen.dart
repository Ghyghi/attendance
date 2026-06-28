import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_status.dart';
import '../domain/module_stats.dart';
import 'attendance_providers.dart';

final moduleStatsProvider =
FutureProvider.autoDispose<List<ModuleStats>>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getModuleStats();
});

/// Student: full attendance history grouped by module, with per-module
/// attendance percentage and a warning when below the minimum.
class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(moduleStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(moduleStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (modules) {
          if (modules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available_outlined,
                        size: 48,
                        color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    const Text(
                      'No attendance records yet.\nSubmit your first attendance to see it here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(moduleStatsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: modules.length,
              itemBuilder: (context, i) => _ModuleSection(stats: modules[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Per-module expandable section ────────────────────────────────────────

class _ModuleSection extends StatelessWidget {
  const _ModuleSection({required this.stats});
  final ModuleStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = stats.attendancePct;
    final isBad = stats.isBelowMinimum;
    final pctColor = isBad ? theme.colorScheme.error : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // ── Header ─────────────────────────────────────────────
        leading: _AttendanceRing(
          pct: pct,
          color: pctColor,
          size: 44,
        ),
        title: Text(
          stats.classroomName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${stats.presentCount} present / ${stats.totalSessions} sessions',
              style: theme.textTheme.bodySmall,
            ),
            if (isBad)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 12, color: theme.colorScheme.error),
                    const SizedBox(width: 4),
                    Text(
                      'Below ${stats.minAttendancePct}% minimum',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // ── Expanded: record list ───────────────────────────────
        children: stats.records.isEmpty
            ? [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No records yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ]
            : [
          const Divider(height: 1),
          ...stats.records.map((r) => _HistoryTile(record: r)),
        ],
      ),
    );
  }
}

// ── Circular attendance indicator ────────────────────────────────────────

class _AttendanceRing extends StatelessWidget {
  const _AttendanceRing(
      {required this.pct, required this.color, required this.size});
  final double pct;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            strokeWidth: 4,
            backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Teacher-edited" pill with the edit timestamp — shown to the student
/// on any of THEIR OWN records that a teacher created or modified
/// directly (mark-absent / status override). Mirrors the same tag shown
/// on the teacher's side (session_detail_screen.dart,
/// attendance_records_screen.dart) so the visual language is consistent
/// across both roles; students get to see it too since it's their own
/// attendance being explained, not privileged teacher-only information.
class _TeacherEditedTag extends StatelessWidget {
  const _TeacherEditedTag({required this.editedAt});
  final DateTime editedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = editedAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Teacher-edited · $dateStr $time',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Individual record tile ────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = record.markedAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

    final (statusLabel, statusColor, statusIcon) = switch (record.status) {
      AttendanceStatus.present =>
      ('Present', Colors.green, Icons.check_circle),
      AttendanceStatus.absent =>
      ('Absent', theme.colorScheme.error, Icons.cancel),
      AttendanceStatus.late =>
      ('Late', Colors.orange, Icons.watch_later_outlined),
    };

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(statusIcon, color: statusColor, size: 22),
      title: Row(
        children: [
          Text(dateStr, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 8),
          // Session code chip — unchanged element, added alongside date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              record.sessionCode,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(time, style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              if (record.gpsVerified)
                Tooltip(
                  message: 'GPS verified',
                  child: Icon(Icons.location_on,
                      size: 12, color: Colors.green.shade700),
                ),
              if (record.faceVerified)
                Tooltip(
                  message: 'Face verified',
                  child:
                  Icon(Icons.face, size: 12, color: Colors.green.shade700),
                ),
            ],
          ),
          if (record.isTeacherEdited) ...[
            const SizedBox(height: 4),
            _TeacherEditedTag(editedAt: record.updatedAt),
          ],
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          statusLabel,
          style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}