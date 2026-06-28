import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/search_picker_screen.dart';
import '../../schools/domain/classroom.dart';
import '../../schools/presentation/classrooms_provider.dart';
import '../domain/attendance_session.dart';
import 'attendance_providers.dart';
import 'session_detail_screen.dart';
import 'sessions_provider.dart';

class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(sessionsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startSession(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Start session'),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('No sessions yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _SessionTile(session: sessions[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    final classrooms = await ref.read(classroomsProvider.future);

    if (!context.mounted) return;
    if (classrooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You have no modules assigned. Ask an admin to add you.'),
      ));
      return;
    }

    final picked = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SearchPickerScreen<Classroom>(
          title: 'Start Session For',
          items: classrooms,
          labelBuilder: (c) => c.name,
          subtitleBuilder: (c) =>
          '${c.sessionTime.label} · ${c.students.length} students',
          idOf: (c) => c.id,
          emptyMessage: 'No modules found.',
        ),
      ),
    );

    if (picked == null || picked.isEmpty || !context.mounted) return;
    final classroomId = picked.first;

    try {
      await ref
          .read(attendanceRepositoryProvider)
          .createSession(classroomId: classroomId);
      ref.invalidate(sessionsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(sessionId: session.id),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: session.isValid
              ? Colors.green.shade100
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            session.isValid ? Icons.qr_code : Icons.qr_code_2_outlined,
            color: session.isValid ? Colors.green.shade800 : null,
          ),
        ),
        title: Text(
          session.code,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        subtitle: Text(
          session.isExpired
              ? 'Expired'
              : session.isActive
              ? 'Active · expires ${_formatTime(session.expiresAt)}'
              : 'Closed',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${session.presentCount} present'),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}