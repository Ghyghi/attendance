import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/widgets/search_picker_screen.dart';
import '../../auth/domain/user.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_session.dart';
import '../domain/attendance_status.dart';
import 'attendance_providers.dart';
import 'session_detail_provider.dart';
import 'sessions_provider.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _timeRemaining(AttendanceSession session) {
    final diff = session.expiresAt.toLocal().difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _closeSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close session?'),
        content: const Text(
            'Students will no longer be able to submit attendance for this session.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Close Session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(attendanceRepositoryProvider)
          .closeSession(widget.sessionId);
      ref.invalidate(sessionDetailProvider(widget.sessionId));
      ref.invalidate(sessionsProvider);
    } on AttendanceException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Teacher marks absent students: fetches the list of students who
  /// have not yet submitted, shows a multi-select picker, then POSTs
  /// the selection to the mark-absent endpoint.
  Future<void> _markAbsent(BuildContext context) async {
    List<User> absentStudents;
    try {
      absentStudents = await ref
          .read(attendanceRepositoryProvider)
          .getAbsentStudents(widget.sessionId);
    } on AttendanceException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!context.mounted) return;

    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All enrolled students have already submitted.'),
      ));
      return;
    }

    final picked = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SearchPickerScreen<User>(
          title: 'Mark as Absent',
          items: absentStudents,
          labelBuilder: (u) => u.fullName,
          subtitleBuilder: (u) => u.username,
          idOf: (u) => u.id,
          multiSelect: true,
          emptyMessage: 'No absent students.',
        ),
      ),
    );

    if (picked == null || picked.isEmpty || !context.mounted) return;

    try {
      await ref.read(attendanceRepositoryProvider).markAbsent(
        sessionId: widget.sessionId,
        studentIds: picked.toList(),
      );
      ref.invalidate(sessionDetailProvider(widget.sessionId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.length} student(s) marked absent.')),
      );
    } on AttendanceException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Teacher flips a single record's status via a bottom sheet.
  Future<void> _overrideRecord(
      BuildContext context, AttendanceRecord record) async {
    final newStatus = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => _StatusPickerSheet(current: record.status),
    );
    if (newStatus == null || !context.mounted) return;

    try {
      await ref.read(attendanceRepositoryProvider).overrideRecordStatus(
        recordId: record.id,
        status: newStatus,
      );
      ref.invalidate(sessionDetailProvider(widget.sessionId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus.')),
      );
    } on AttendanceException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(sessionDetailProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(sessionDetailProvider(widget.sessionId)),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (detail) => _SessionDetailBody(
          detail: detail,
          onClose: () => _closeSession(context),
          onMarkAbsent: () => _markAbsent(context),
          onOverrideRecord: (r) => _overrideRecord(context, r),
          formatCountdown: _formatCountdown,
          timeRemaining: _timeRemaining,
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────

class _SessionDetailBody extends StatelessWidget {
  const _SessionDetailBody({
    required this.detail,
    required this.onClose,
    required this.onMarkAbsent,
    required this.onOverrideRecord,
    required this.formatCountdown,
    required this.timeRemaining,
  });

  final SessionDetail detail;
  final VoidCallback onClose;
  final VoidCallback onMarkAbsent;
  final void Function(AttendanceRecord) onOverrideRecord;
  final String Function(Duration) formatCountdown;
  final Duration Function(AttendanceSession) timeRemaining;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final records = detail.records;
    final remaining = timeRemaining(session);
    final isExpiringSoon = remaining.inMinutes < 3 && session.isValid;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status banner ──────────────────────────────────────
          _StatusBanner(session: session),
          const SizedBox(height: 16),

          // ── QR code card ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (session.qrImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${ApiConfig.baseUrl}${session.qrImage}',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _QrPlaceholder(),
                        loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                              child: CircularProgressIndicator()),
                        ),
                      ),
                    )
                  else
                    const _QrPlaceholder(),
                  const SizedBox(height: 20),

                  // Code chip (tap to copy)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: session.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied.')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            session.code,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_outlined,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Countdown
                  if (session.isValid)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 16,
                            color: isExpiringSoon
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Expires in ${formatCountdown(remaining)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isExpiringSoon
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isExpiringSoon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      session.isExpired ? 'Expired' : 'Closed by teacher',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats row ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.check_circle_outline,
                  label: 'Present',
                  value: '${session.presentCount}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  icon: Icons.people_outline,
                  label: 'Records',
                  value: '${records.length}',
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Teacher action buttons ───────────────────────────────
          Row(
            children: [
              // Mark absent — always visible so teachers can act after session ends
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMarkAbsent,
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Mark Absent'),
                ),
              ),
              const SizedBox(width: 8),
              if (session.isValid)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Records list ─────────────────────────────────────────
          Text('Attendance Records',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No students have submitted yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ...records.map((r) => _RecordTile(
              record: r,
              onOverride: () => onOverrideRecord(r),
            )),
        ],
      ),
    );
  }
}

// ── Status picker bottom sheet ───────────────────────────────────────────

class _StatusPickerSheet extends StatelessWidget {
  const _StatusPickerSheet({required this.current});
  final AttendanceStatus current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Override Status',
                  style: theme.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            for (final s in AttendanceStatus.values)
              ListTile(
                leading: Icon(
                  _iconFor(s),
                  color: _colorFor(s, theme),
                ),
                title: Text(s.toApi()[0].toUpperCase() + s.toApi().substring(1)),
                trailing: s == current
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(s.toApi()),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => Icons.check_circle,
    AttendanceStatus.absent => Icons.cancel_outlined,
    AttendanceStatus.late => Icons.watch_later_outlined,
  };

  Color _colorFor(AttendanceStatus s, ThemeData theme) => switch (s) {
    AttendanceStatus.present => Colors.green,
    AttendanceStatus.absent => theme.colorScheme.error,
    AttendanceStatus.late => Colors.orange,
  };
}

// ── Sub-widgets ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.session});
  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon, bg, fg) = session.isValid
        ? ('Active', Icons.radio_button_on, Colors.green.shade50,
    Colors.green.shade800)
        : session.isExpired
        ? ('Expired', Icons.timer_off_outlined,
    theme.colorScheme.errorContainer,
    theme.colorScheme.onErrorContainer)
        : ('Closed', Icons.lock_outline,
    theme.colorScheme.surfaceContainerHighest,
    theme.colorScheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(color: fg)),
      ]),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.qr_code_2,
          size: 80,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.icon,
        required this.label,
        required this.value,
        required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                    Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}

/// Small "Teacher-edited" pill — shown on any record a teacher created or
/// modified directly (mark-absent / status override), so it's visually
/// clear which records reflect the student's own submission vs a manual
/// correction. One generic tag regardless of which action touched the
/// record — the UI doesn't distinguish mark-absent from override.
/// Includes the timestamp of the teacher's edit (record.updatedAt) rather
/// than the original submission time, since that's the moment this tag
/// is actually describing.
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

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onOverride});
  final AttendanceRecord record;
  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = record.studentDetail;
    final (statusColor, statusIcon) = switch (record.status) {
      AttendanceStatus.present => (Colors.green, Icons.check_circle),
      AttendanceStatus.absent =>
      (theme.colorScheme.error, Icons.cancel),
      AttendanceStatus.late => (Colors.orange, Icons.watch_later_outlined),
    };

    final local = record.markedAt.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(student.firstName.isNotEmpty
              ? student.firstName[0].toUpperCase()
              : student.username[0].toUpperCase()),
        ),
        title: Text(
          student.fullName,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (record.gpsVerified)
                const Tooltip(
                    message: 'GPS verified',
                    child: Icon(Icons.location_on,
                        size: 12, color: Colors.green)),
              if (record.faceVerified)
                const Tooltip(
                    message: 'Face verified',
                    child: Icon(Icons.face, size: 12, color: Colors.green)),
              const SizedBox(width: 4),
              Text(timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ]),
            if (record.isTeacherEdited) ...[
              const SizedBox(height: 4),
              _TeacherEditedTag(editedAt: record.updatedAt),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor),
            // Override button — lets teacher flip the status
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Override status',
              onPressed: onOverride,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}