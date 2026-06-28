import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../users/presentation/create_user_screen.dart';
import '../../users/presentation/user_list_providers.dart';
import '../../users/presentation/user_list_screen.dart';
import '../domain/classroom.dart';
import 'classroom_detail_screen.dart';
import 'classrooms_provider.dart';
import 'create_classroom_screen.dart';

/// Lists modules visible to the current user.
/// Admins see their whole school; teachers see only modules they're in.
///
/// Search bar mirrors UserListScreen's pattern (TextEditingController ->
/// lowercased query -> client-side filter) — same widget shape, same
/// debounce-free "filter on every keystroke" approach, since the
/// underlying list is already small/local once fetched. Matches against
/// the module name AND any assigned teacher's full name, so an admin can
/// search "who teaches X" as well as "find module X" in one box.
class ClassroomListScreen extends ConsumerStatefulWidget {
  const ClassroomListScreen({super.key});

  @override
  ConsumerState<ClassroomListScreen> createState() =>
      _ClassroomListScreenState();
}

class _ClassroomListScreenState extends ConsumerState<ClassroomListScreen> {
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
      final teacherMatch = c.teachers
          .any((t) => t.fullName.toLowerCase().contains(_query));
      return nameMatch || teacherMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);
    final authState = ref.watch(authControllerProvider);
    final isAdmin =
        authState is AuthAuthenticated && authState.user.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(classroomsProvider),
          ),
        ],
      ),
      floatingActionButton: isAdmin ? const _AdminFab() : null,
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
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error.toString(), textAlign: TextAlign.center),
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
                          Text(
                            isAdmin
                                ? 'No modules yet.\nTap + to create one.'
                                : 'No modules assigned to you yet.\nAsk an admin to add you.',
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ClassroomTile(classroom: filtered[index]),
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

class _ClassroomTile extends StatelessWidget {
  const _ClassroomTile({required this.classroom});
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      '${classroom.students.length} students',
      classroom.sessionTime.label,
    ];
    if (classroom.numSessions > 0) {
      subtitleParts.insert(0, '${classroom.numSessions} sessions');
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.class_outlined,
              color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(classroom.name),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ClassroomDetailScreen(classroomId: classroom.id),
          ),
        ),
      ),
    );
  }
}

// ── Admin speed-dial FAB ─────────────────────────────────────────────────

class _AdminFab extends ConsumerStatefulWidget {
  const _AdminFab();

  @override
  ConsumerState<_AdminFab> createState() => _AdminFabState();
}

class _AdminFabState extends ConsumerState<_AdminFab> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          _FabOption(
            icon: Icons.person_add_outlined,
            label: 'New User',
            onTap: () async {
              setState(() => _expanded = false);
              final created = await Navigator.of(context).push<User>(
                MaterialPageRoute(builder: (_) => const CreateUserScreen()),
              );
              if (created == null) return;
              if (created.role == UserRole.teacher) {
                ref.invalidate(teachersProvider);
              } else if (created.role == UserRole.student) {
                ref.invalidate(studentsProvider);
              }
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UserListScreen(highlightRole: created.role),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _FabOption(
            icon: Icons.add_box_outlined,
            label: 'New Module',
            onTap: () async {
              setState(() => _expanded = false);
              final result = await Navigator.of(context).push<Classroom>(
                MaterialPageRoute(
                    builder: (_) => const CreateClassroomScreen()),
              );
              if (result == null) return;
              ref.invalidate(classroomsProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                    content: Text('Module "${result.name}" created.')));
            },
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          heroTag: 'admin_fab_main',
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Icon(_expanded ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

class _FabOption extends StatelessWidget {
  const _FabOption(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: '${label}_fab',
      onPressed: onTap,
      label: Text(label),
      icon: Icon(icon),
    );
  }
}