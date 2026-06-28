import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/search_picker_screen.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../users/data/users_repository.dart';
import '../../users/presentation/users_providers.dart';
import '../data/schools_repository.dart';
import '../domain/classroom.dart';
import 'classroom_detail_provider.dart';
import 'classrooms_provider.dart';
import 'schools_providers.dart';

/// Sort order for the students list. Defaults to name (alphabetical, the
/// order the backend already returns them in) — attendance asc/desc are
/// reached by tapping the sort control, available to both admin and
/// teacher viewers of this screen (anyone who can see the roster at all).
enum _StudentSortMode {
  name,
  attendanceDesc,
  attendanceAsc;

  /// Cycles name -> attendance (highest first) -> attendance (lowest
  /// first) -> back to name, so one tap always has a well-defined next
  /// state rather than needing a menu.
  _StudentSortMode get next => switch (this) {
    _StudentSortMode.name => _StudentSortMode.attendanceDesc,
    _StudentSortMode.attendanceDesc => _StudentSortMode.attendanceAsc,
    _StudentSortMode.attendanceAsc => _StudentSortMode.name,
  };

  String get label => switch (this) {
    _StudentSortMode.name => 'Name',
    _StudentSortMode.attendanceDesc => 'Attendance (high → low)',
    _StudentSortMode.attendanceAsc => 'Attendance (low → high)',
  };

  IconData get icon => switch (this) {
    _StudentSortMode.name => Icons.sort_by_alpha,
    _StudentSortMode.attendanceDesc => Icons.arrow_downward,
    _StudentSortMode.attendanceAsc => Icons.arrow_upward,
  };
}

class ClassroomDetailScreen extends ConsumerStatefulWidget {
  const ClassroomDetailScreen({super.key, required this.classroomId});

  final String classroomId;

  @override
  ConsumerState<ClassroomDetailScreen> createState() =>
      _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState
    extends ConsumerState<ClassroomDetailScreen> {
  _StudentSortMode _sortMode = _StudentSortMode.name;

  /// Returns a NEW sorted list — never mutates classroom.students, since
  /// that list is owned by the (cached) Classroom model and reused as-is
  /// elsewhere (e.g. id sets passed to add/remove pickers).
  List<User> _sortedStudents(List<User> students) {
    final sorted = [...students];
    switch (_sortMode) {
      case _StudentSortMode.name:
        sorted.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      case _StudentSortMode.attendanceDesc:
        sorted.sort((a, b) =>
            (b.attendancePct ?? 0).compareTo(a.attendancePct ?? 0));
      case _StudentSortMode.attendanceAsc:
        sorted.sort((a, b) =>
            (a.attendancePct ?? 0).compareTo(b.attendancePct ?? 0));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final classroomId = widget.classroomId;
    final classroomAsync = ref.watch(classroomDetailProvider(classroomId));
    final authState = ref.watch(authControllerProvider);
    final isAdmin = authState is AuthAuthenticated &&
        authState.user.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: classroomAsync.when(
          data: (c) => Text(c.name),
          loading: () => const Text('Module'),
          error: (_, __) => const Text('Module'),
        ),
        actions: [
          // Edit button — admin only
          if (isAdmin)
            classroomAsync.when(
              data: (c) => IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit module info',
                onPressed: () => _showEditSheet(context, ref, c),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
      body: classroomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (classroom) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(classroomDetailProvider(classroomId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Module info card ─────────────────────────────
              _ModuleInfoCard(classroom: classroom),
              const SizedBox(height: 16),

              // ── Teachers ─────────────────────────────────────
              _SectionHeader(
                title: 'Teachers (${classroom.teachers.length})',
                action: isAdmin
                    ? IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  tooltip: 'Add teacher',
                  onPressed: () => _addTeacher(context, ref,
                      classroom.id,
                      classroom.teachers.map((t) => t.id).toSet()),
                )
                    : null,
              ),
              if (classroom.teachers.isEmpty)
                const _EmptyHint('No teachers assigned.')
              else
                ...classroom.teachers.map(
                      (t) => _UserTile(
                    user: t,
                    trailing: isAdmin
                        ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      tooltip: 'Remove teacher',
                      onPressed: () => _removeTeacher(
                          context, ref, classroom.id, t),
                    )
                        : null,
                  ),
                ),
              const SizedBox(height: 16),

              // ── Students ─────────────────────────────────────
              _SectionHeader(
                title: 'Students (${classroom.students.length})',
                action: isAdmin
                    ? IconButton(
                  icon: const Icon(Icons.group_add_outlined),
                  tooltip: 'Add students',
                  onPressed: () => _addStudents(context, ref,
                      classroom.id,
                      classroom.students.map((s) => s.id).toSet()),
                )
                    : null,
              ),
              if (classroom.students.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _sortMode = _sortMode.next),
                      icon: Icon(_sortMode.icon, size: 16),
                      label: Text(
                        'Sort: ${_sortMode.label}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
              if (classroom.students.isEmpty)
                const _EmptyHint('No students yet.')
              else
                ..._sortedStudents(classroom.students).map(
                      (s) => _UserTile(
                    user: s,
                    trailing: isAdmin
                        ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      tooltip: 'Remove from module',
                      onPressed: () => _removeStudent(
                          context, ref, classroom.id, s),
                    )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit module info ─────────────────────────────────────────────

  void _showEditSheet(
      BuildContext context, WidgetRef ref, Classroom classroom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditModuleSheet(
        classroom: classroom,
        onSaved: () {
          ref.invalidate(classroomDetailProvider(widget.classroomId));
          ref.invalidate(classroomsProvider);
        },
      ),
    );
  }

  // ── Teacher management ───────────────────────────────────────────

  Future<void> _addTeacher(BuildContext context, WidgetRef ref,
      String classroomId, Set<String> currentTeacherIds) async {
    final List<User> allTeachers;
    try {
      allTeachers = await ref
          .read(usersRepositoryProvider)
          .listUsers(role: UserRole.teacher);
    } on UsersException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    final eligible =
    allTeachers.where((t) => !currentTeacherIds.contains(t.id)).toList();

    if (!context.mounted) return;
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All teachers are already assigned.'),
      ));
      return;
    }

    final picked = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SearchPickerScreen<User>(
          title: 'Add Teachers',
          items: eligible,
          labelBuilder: (u) => u.fullName,
          subtitleBuilder: (u) => u.username,
          idOf: (u) => u.id,
          multiSelect: true,
          emptyMessage: 'No teachers found.',
        ),
      ),
    );

    if (picked == null || picked.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(schoolsRepositoryProvider)
          .addTeachersToClassroom(classroomId, picked);
      ref.invalidate(classroomDetailProvider(classroomId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.length} teacher(s) added.')),
      );
    } on SchoolsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeTeacher(BuildContext context, WidgetRef ref,
      String classroomId, User teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove teacher?'),
        content: Text('Remove ${teacher.fullName} from this module?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(schoolsRepositoryProvider)
          .removeTeacherFromClassroom(classroomId, teacher.id);
      ref.invalidate(classroomDetailProvider(classroomId));
    } on SchoolsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Student management ───────────────────────────────────────────

  Future<void> _addStudents(BuildContext context, WidgetRef ref,
      String classroomId, Set<String> currentStudentIds) async {
    final List<User> allStudents;
    try {
      allStudents = await ref
          .read(usersRepositoryProvider)
          .listUsers(role: UserRole.student);
    } on UsersException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    final eligible =
    allStudents.where((s) => !currentStudentIds.contains(s.id)).toList();

    if (!context.mounted) return;
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All students are already in this module.'),
      ));
      return;
    }

    final picked = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SearchPickerScreen<User>(
          title: 'Add Students',
          items: eligible,
          labelBuilder: (u) => u.fullName,
          subtitleBuilder: (u) => u.username,
          idOf: (u) => u.id,
          multiSelect: true,
          emptyMessage: 'No eligible students found.',
        ),
      ),
    );

    if (picked == null || picked.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(schoolsRepositoryProvider)
          .addStudentsToClassroom(classroomId, picked);
      ref.invalidate(classroomDetailProvider(classroomId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.length} student(s) added.')),
      );
    } on SchoolsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeStudent(BuildContext context, WidgetRef ref,
      String classroomId, User student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
            'Remove ${student.fullName}? Their attendance records will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(schoolsRepositoryProvider)
          .removeStudentFromClassroom(classroomId, student.id);
      ref.invalidate(classroomDetailProvider(classroomId));
    } on SchoolsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// ── Edit module bottom sheet ──────────────────────────────────────────────

class _EditModuleSheet extends ConsumerStatefulWidget {
  const _EditModuleSheet({
    required this.classroom,
    required this.onSaved,
  });

  final Classroom classroom;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditModuleSheet> createState() => _EditModuleSheetState();
}

class _EditModuleSheetState extends ConsumerState<_EditModuleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numSessionsController;
  late final TextEditingController _minPctController;
  late SessionTime _sessionTime;
  late DateTime? _beginDate;
  late DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.classroom;
    _nameController = TextEditingController(text: c.name);
    _numSessionsController =
        TextEditingController(text: c.numSessions.toString());
    _minPctController =
        TextEditingController(text: c.minAttendancePct.toString());
    _sessionTime = c.sessionTime;
    _beginDate = c.beginDate;
    _endDate = c.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numSessionsController.dispose();
    _minPctController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isBegin}) async {
    final initial = isBegin
        ? (_beginDate ?? DateTime.now())
        : (_endDate ?? (_beginDate ?? DateTime.now()));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isBegin) {
        _beginDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final c = widget.classroom;
    try {
      await ref.read(schoolsRepositoryProvider).updateClassroom(
        id: c.id,
        school: c.school,
        name: _nameController.text.trim(),
        numSessions: int.tryParse(_numSessionsController.text) ?? 0,
        minAttendancePct:
        (int.tryParse(_minPctController.text) ?? 75).clamp(0, 100),
        beginDate: _beginDate,
        endDate: _endDate,
        sessionTime: _sessionTime,
        teacherIds: c.teachers.map((t) => t.id).toList(),
        studentIds: c.students.map((s) => s.id).toList(),
      );

      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module updated.')),
      );
    } on SchoolsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Module', style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Module name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Sessions + min attendance
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numSessionsController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Total sessions',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0) return '≥ 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minPctController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Min attendance %',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 100) return '0–100';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Session time
              DropdownButtonFormField<SessionTime>(
                value: _sessionTime,
                decoration: const InputDecoration(
                  labelText: 'When (time of day)',
                  border: OutlineInputBorder(),
                ),
                items: SessionTime.values
                    .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label),
                ))
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (v) => setState(() => _sessionTime = v!),
              ),
              const SizedBox(height: 12),

              // Date range
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickDate(isBegin: true),
                      icon: const Icon(Icons.calendar_today_outlined,
                          size: 16),
                      label: Text(
                        'Start: ${_fmtDate(_beginDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickDate(isBegin: false),
                      icon:
                      const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        'End: ${_fmtDate(_endDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────

class _ModuleInfoCard extends StatelessWidget {
  const _ModuleInfoCard({required this.classroom});
  final Classroom classroom;

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(classroom.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _InfoRow(
                icon: Icons.event_note_outlined,
                label: 'Sessions',
                value: classroom.numSessions == 0
                    ? 'Not set'
                    : classroom.numSessions.toString()),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.percent,
                label: 'Min attendance',
                value: '${classroom.minAttendancePct}%'),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Time of day',
                value: classroom.sessionTime.label),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.date_range_outlined,
                label: 'Period',
                value:
                '${_fmtDate(classroom.beginDate)} → ${_fmtDate(classroom.endDate)}'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Expanded(
          child: Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.trailing});
  final User user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pct = user.attendancePct;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user.firstName.isNotEmpty
              ? user.firstName[0].toUpperCase()
              : user.username[0].toUpperCase()),
        ),
        title: Text(user.fullName),
        // Shows the username plus an attendance % badge whenever this User
        // carries attendancePct data — i.e. came from a classroom's
        // students_detail (apps/schools/serializers.py). Teachers never
        // have this field set, so their tile renders exactly as before.
        subtitle: pct == null
            ? Text(user.username)
            : Row(
          children: [
            Text(user.username),
            const SizedBox(width: 8),
            _AttendancePctBadge(pct: pct),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}

/// Small attendance-percentage pill shown next to a student's username
/// in the module detail screen. Tinted red below the module's minimum
/// threshold isn't done here since this badge doesn't know the module's
/// min_attendance_pct in this context — it's a neutral color regardless
/// of value, just the raw number for the admin/teacher to read at a glance.
class _AttendancePctBadge extends StatelessWidget {
  const _AttendancePctBadge({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}% attendance',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}