import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/classroom.dart';
import 'classrooms_provider.dart';

/// Student: read-only view of modules they are enrolled in.
/// Each card is an ExpansionTile — collapsed it shows the module name
/// and key stats; expanded it reveals teachers, dates, session time,
/// and the enrolled-student count so the student has full module context
/// without navigating away.
///
/// Search bar added on the same pattern as ClassroomListScreen /
/// UserListScreen — matches module name and assigned teacher name(s).
class StudentClassroomsScreen extends ConsumerStatefulWidget {
  const StudentClassroomsScreen({super.key});

  @override
  ConsumerState<StudentClassroomsScreen> createState() =>
      _StudentClassroomsScreenState();
}

class _StudentClassroomsScreenState
    extends ConsumerState<StudentClassroomsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Classroom> _filtered(List<Classroom> classrooms) {
    if (_query.isEmpty) return classrooms;
    return classrooms.where((c) {
      final nameMatch = c.name.toLowerCase().contains(_query);
      final teacherMatch =
      c.teachers.any((t) => t.fullName.toLowerCase().contains(_query));
      return nameMatch || teacherMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Modules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(classroomsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by module or teacher name…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: classroomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), textAlign: TextAlign.center),
                ),
              ),
              data: (classrooms) {
                if (classrooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.class_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text(
                            'You are not enrolled in any modules yet.\nAsk your admin to add you.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final filtered = _filtered(classrooms);
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No modules match "$_query".',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(classroomsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _ModuleCard(classroom: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.classroom});
  final Classroom classroom;

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacherNames = classroom.teachers.isEmpty
        ? 'No teacher assigned'
        : classroom.teachers.map((t) => t.fullName).join(', ');

    // Collapsed subtitle: teacher name(s) + session time
    final collapsedSubtitle = [
      teacherNames,
      classroom.sessionTime.label,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // ── Collapsed header ──────────────────────────────────
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.class_outlined,
              color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(
          classroom.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          collapsedSubtitle,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AttendanceBadge(pct: classroom.minAttendancePct),
            const SizedBox(width: 4),
            // Default ExpansionTile chevron rendered by the widget itself
          ],
        ),

        // ── Expanded detail ───────────────────────────────────
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teachers section
                Text('Teachers',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (classroom.teachers.isEmpty)
                  _DetailRow(
                    icon: Icons.school_outlined,
                    text: 'No teacher assigned',
                    muted: true,
                  )
                else
                  ...classroom.teachers.map(
                        (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _DetailRow(
                        icon: Icons.school_outlined,
                        text: t.fullName,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Schedule
                Text('Schedule',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  text: classroom.sessionTime.label,
                ),
                const SizedBox(height: 4),
                _DetailRow(
                  icon: Icons.date_range_outlined,
                  text:
                  '${_fmtDate(classroom.beginDate)} → ${_fmtDate(classroom.endDate)}',
                ),
                const SizedBox(height: 12),

                // Module stats
                Text('Module',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.event_note_outlined,
                  text: classroom.numSessions == 0
                      ? 'Total sessions not set'
                      : '${classroom.numSessions} planned sessions',
                ),
                const SizedBox(height: 4),
                _DetailRow(
                  icon: Icons.percent,
                  text:
                  'Minimum ${classroom.minAttendancePct}% attendance required',
                ),
                const SizedBox(height: 4),
                _DetailRow(
                  icon: Icons.people_outline,
                  text:
                  '${classroom.students.length} student${classroom.students.length == 1 ? "" : "s"} enrolled',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  const _AttendanceBadge({required this.pct});
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Minimum attendance required',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$pct% min',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}