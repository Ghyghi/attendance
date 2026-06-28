import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../schools/presentation/classrooms_provider.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_session.dart';
import '../domain/attendance_status.dart';
import 'attendance_providers.dart';
import 'session_detail_screen.dart';
import 'sessions_provider.dart';

// ── Data models ───────────────────────────────────────────────────────────

class _SessionWithRecords {
  const _SessionWithRecords({required this.session, required this.records});
  final AttendanceSession session;
  final List<AttendanceRecord> records;
}

class _ClassroomGroup {
  _ClassroomGroup({required this.classroomId, required this.classroomName});
  final String classroomId;
  final String classroomName;
  final List<_SessionWithRecords> sessions = [];
}

// ── Provider ─────────────────────────────────────────────────────────────

/// Fetches sessions + their records in parallel, then groups by classroom.
/// Also fetches the teacher's classrooms to resolve classroom names.
final _allRecordsProvider =
FutureProvider.autoDispose<List<_ClassroomGroup>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);

  // Fetch sessions and classroom list concurrently.
  final results = await Future.wait([
    repo.listSessions(),
    ref.watch(classroomsProvider.future),
  ]);

  final sessions = results[0] as dynamic;
  final classrooms = results[1] as dynamic;

  // Build a name lookup map from the classrooms list.
  final Map<String, String> classroomNames = {
    for (final c in classrooms) c.id as String: c.name as String,
  };

  if ((sessions as List).isEmpty) return [];

  // Parallel record fetch — one call per session.
  final pairs = await Future.wait(
    sessions.map((s) async {
      final records = await repo.getSessionRecords(s.id as String);
      return _SessionWithRecords(session: s, records: records);
    }),
  );

  // Group by classroom, preserving newest-first order within each group.
  final Map<String, _ClassroomGroup> byClass = {};
  for (final pair in pairs) {
    final cid = pair.session.classroom;
    byClass.putIfAbsent(
      cid,
          () => _ClassroomGroup(
        classroomId: cid,
        classroomName: classroomNames[cid] ?? 'Module $cid',
      ),
    );
    byClass[cid]!.sessions.add(pair);
  }

  return byClass.values.toList();
});

// ── Screen ────────────────────────────────────────────────────────────────

/// Teacher: attendance records grouped by module (classroom), then by
/// session. Each session row shows its date and code. Tapping the
/// open-in-new icon navigates to the full SessionDetailScreen.
class AttendanceRecordsScreen extends ConsumerWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(_allRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_allRecordsProvider);
              ref.invalidate(classroomsProvider);
            },
          ),
        ],
      ),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(child: Text('No sessions yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_allRecordsProvider);
              ref.invalidate(classroomsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, i) =>
                  _ClassroomSection(group: groups[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Classroom (module) section ────────────────────────────────────────────

class _ClassroomSection extends StatelessWidget {
  const _ClassroomSection({required this.group});
  final _ClassroomGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPresent = group.sessions
        .expand((s) => s.records)
        .where((r) => r.status == AttendanceStatus.present)
        .length;
    final totalRecords =
    group.sessions.fold(0, (sum, s) => sum + s.records.length);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.class_outlined,
              color: theme.colorScheme.onPrimaryContainer, size: 18),
        ),
        title: Text(
          group.classroomName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${group.sessions.length} session${group.sessions.length == 1 ? "" : "s"} · '
              '$totalPresent/$totalRecords present',
          style: theme.textTheme.bodySmall,
        ),
        children: group.sessions
            .map((s) => _SessionGroup(
          data: s,
          onTap: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) =>
                SessionDetailScreen(sessionId: s.session.id),
          )),
        ))
            .toList(),
      ),
    );
  }
}

// ── Session row inside a classroom section ────────────────────────────────

class _SessionGroup extends StatelessWidget {
  const _SessionGroup({required this.data, required this.onTap});
  final _SessionWithRecords data;
  final void Function(BuildContext) onTap;

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = data.session;
    final records = data.records;
    final presentCount =
        records.where((r) => r.status == AttendanceStatus.present).length;
    final sessionDate = _fmtDate(session.createdAt);

    final statusColor = session.isValid
        ? Colors.green
        : session.isExpired
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: statusColor.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          session.isValid ? Icons.qr_code : Icons.qr_code_2_outlined,
          color: statusColor,
          size: 20,
        ),
        title: Row(
          children: [
            Text(
              session.code,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            // Date of the session
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sessionDate,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${session.isValid ? "Active" : session.isExpired ? "Expired" : "Closed"}'
              ' · $presentCount/${records.length} present',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 16),
              tooltip: 'Open session detail',
              onPressed: () => onTap(context),
              constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        children: records.isEmpty
            ? [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'No records yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ]
            : records
            .map((r) => _CompactRecordTile(record: r))
            .toList(),
      ),
    );
  }
}

// ── Compact record row ────────────────────────────────────────────────────

String _editedTimeStr(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _CompactRecordTile extends StatelessWidget {
  const _CompactRecordTile({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = record.studentDetail;
    final (color, icon) = switch (record.status) {
      AttendanceStatus.present => (Colors.green, Icons.check_circle),
      AttendanceStatus.absent =>
      (theme.colorScheme.error, Icons.cancel_outlined),
      AttendanceStatus.late => (Colors.orange, Icons.watch_later_outlined),
    };

    final local = record.markedAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CircleAvatar(
        radius: 16,
        child: Text(
          student.firstName.isNotEmpty
              ? student.firstName[0].toUpperCase()
              : student.username[0].toUpperCase(),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              student.fullName,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (record.isTeacherEdited) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                // Date omitted here (unlike the other two teacher-edited
                // tag locations) — this tile already sits under a
                // session/date header in the parent ExpansionTile, so
                // repeating the date would be redundant in this
                // already-compact, dense row.
                'Teacher-edited · ${_editedTimeStr(record.updatedAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(time, style: theme.textTheme.bodySmall),
      trailing: Icon(icon, color: color, size: 18),
    );
  }
}