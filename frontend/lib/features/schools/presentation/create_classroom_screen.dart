import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/search_picker_screen.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../users/presentation/users_providers.dart';
import '../data/schools_repository.dart';
import '../domain/classroom.dart';
import 'schools_providers.dart';

/// Admin: create a Module with name, session metadata, and an initial
/// teacher roster. Students are added after creation via the detail screen.
class CreateClassroomScreen extends ConsumerStatefulWidget {
  const CreateClassroomScreen({super.key});

  @override
  ConsumerState<CreateClassroomScreen> createState() =>
      _CreateClassroomScreenState();
}

class _CreateClassroomScreenState extends ConsumerState<CreateClassroomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numSessionsController = TextEditingController(text: '0');
  final _minPctController = TextEditingController(text: '75');

  SessionTime _sessionTime = SessionTime.day;
  DateTime? _beginDate;
  DateTime? _endDate;

  final Set<String> _selectedTeacherIds = {};
  List<User> _allTeachers = [];
  bool _isLoadingTeachers = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoadingTeachers = true);
    try {
      final teachers = await ref
          .read(usersRepositoryProvider)
          .listUsers(role: UserRole.teacher);
      if (mounted) setState(() => _allTeachers = teachers);
    } catch (_) {
      // Non-fatal — picker retries on open.
    } finally {
      if (mounted) setState(() => _isLoadingTeachers = false);
    }
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
        // Auto-clear end date if it's before the new begin date.
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTeachers(BuildContext context) async {
    try {
      final fresh = await ref
          .read(usersRepositoryProvider)
          .listUsers(role: UserRole.teacher);
      if (mounted) setState(() => _allTeachers = fresh);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }

    if (!context.mounted) return;
    if (_allTeachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No teachers in your school yet. Create one first.'),
      ));
      return;
    }

    final picked = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SearchPickerScreen<User>(
          title: 'Assign Teachers',
          items: _allTeachers,
          labelBuilder: (u) => u.fullName,
          subtitleBuilder: (u) => u.username,
          idOf: (u) => u.id,
          multiSelect: true,
          initiallySelectedIds: Set.of(_selectedTeacherIds),
          emptyMessage: 'No teachers found.',
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedTeacherIds
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) return;
    final schoolId = authState.user.school;
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No school assigned to your account.')));
      return;
    }

    final numSessions = int.tryParse(_numSessionsController.text) ?? 0;
    final minPct = int.tryParse(_minPctController.text) ?? 75;

    setState(() => _isSubmitting = true);
    try {
      final classroom = await ref.read(schoolsRepositoryProvider).createClassroom(
        school: schoolId,
        name: _nameController.text.trim(),
        numSessions: numSessions,
        minAttendancePct: minPct.clamp(0, 100),
        beginDate: _beginDate,
        endDate: _endDate,
        sessionTime: _sessionTime,
        teacherIds: _selectedTeacherIds.toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(classroom);
    } on SchoolsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedTeachers = _allTeachers
        .where((t) => _selectedTeacherIds.contains(t.id))
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Module')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Module name ──────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Module name',
                    hintText: 'e.g. Advanced Mathematics',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // ── Session metadata ──────────────────────────────
                Text('Session Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),

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
                          if (n == null || n < 0) return 'Enter a number ≥ 0';
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
                          if (n == null || n < 0 || n > 100) {
                            return '0–100';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Session time picker ───────────────────────────
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

                // ── Date range ────────────────────────────────────
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
                          'Start: ${_formatDate(_beginDate)}',
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
                          'End: ${_formatDate(_endDate)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Teacher picker ────────────────────────────────
                Text('Teachers',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: (_isSubmitting || _isLoadingTeachers)
                      ? null
                      : () => _pickTeachers(context),
                  icon: _isLoadingTeachers
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.person_search_outlined),
                  label: Text(_selectedTeacherIds.isEmpty
                      ? 'Assign Teachers (optional)'
                      : 'Edit Teachers (${_selectedTeacherIds.length} selected)'),
                ),
                if (selectedTeachers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selectedTeachers
                        .map((t) => Chip(
                      label: Text(t.fullName),
                      avatar: const Icon(Icons.school_outlined,
                          size: 16),
                      onDeleted: _isSubmitting
                          ? null
                          : () => setState(
                              () => _selectedTeacherIds.remove(t.id)),
                    ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 28),

                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Create Module'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}