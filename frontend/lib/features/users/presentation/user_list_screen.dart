import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';
import '../data/users_repository.dart';
import 'create_user_screen.dart';
import 'user_list_providers.dart';
import 'users_providers.dart';

/// Admin: browse all users in their school, filtered by role tab and
/// an inline search. Navigated to automatically after creating a user
/// (from classroom_list_screen's FAB) so the admin can confirm the
/// account appears before doing anything else.
class UserListScreen extends ConsumerStatefulWidget {
  /// When non-null, the screen opens on the tab matching this role so
  /// the newly created user is immediately visible.
  const UserListScreen({super.key, this.highlightRole});

  final UserRole? highlightRole;

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _query = '';

  static const _roleTabs = [null, UserRole.teacher, UserRole.student];
  static const _tabLabels = ['All', 'Teachers', 'Students'];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.highlightRole == null
        ? 0
        : _roleTabs.indexOf(widget.highlightRole);
    _tabs = TabController(
      length: _roleTabs.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        bottom: TabBar(
          controller: _tabs,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(teachersProvider);
              ref.invalidate(studentsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createUser(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('New User'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or username…',
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
            child: TabBarView(
              controller: _tabs,
              children: _roleTabs
                  .map((role) => _UserTab(role: role, query: _query))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createUser(BuildContext context) async {
    final created = await Navigator.of(context).push<User>(
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );
    if (created == null) return;

    // Invalidate so the list refreshes, then switch to the right tab.
    if (created.role == UserRole.teacher) {
      ref.invalidate(teachersProvider);
      _tabs.animateTo(1);
    } else if (created.role == UserRole.student) {
      ref.invalidate(studentsProvider);
      _tabs.animateTo(2);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${created.role == UserRole.teacher ? "Teacher" : "Student"} '
              '"${created.fullName}" created.',
        ),
      ));
  }
}

/// One tab — loads users for [role] (null = all) and filters client-side
/// by [query]. Uses the pre-existing teachersProvider / studentsProvider
/// when filtered, or fetches all when role is null.
class _UserTab extends ConsumerWidget {
  const _UserTab({required this.role, required this.query});

  final UserRole? role;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For the "All" tab we need both lists merged — watch both and combine.
    if (role == null) {
      final teachersAsync = ref.watch(teachersProvider);
      final studentsAsync = ref.watch(studentsProvider);

      return teachersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (teachers) => studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString()),
          data: (students) {
            final all = [...teachers, ...students];
            return _UserList(users: all, query: query);
          },
        ),
      );
    }

    final provider = role == UserRole.teacher ? teachersProvider : studentsProvider;
    final usersAsync = ref.watch(provider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (users) => _UserList(users: users, query: query),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users, required this.query});

  final List<User> users;
  final String query;

  List<User> get _filtered {
    if (query.isEmpty) return users;
    return users.where((u) {
      return u.fullName.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                query.isEmpty ? 'No users yet.' : 'No results for "$query".',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _UserTile(user: filtered[i]),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = switch (user.role) {
      UserRole.teacher => Colors.indigo,
      UserRole.student => Colors.teal,
      UserRole.admin => Colors.deepOrange,
    };
    final roleLabel = switch (user.role) {
      UserRole.teacher => 'Teacher',
      UserRole.student => 'Student',
      UserRole.admin => 'Admin',
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            user.firstName.isNotEmpty
                ? user.firstName[0].toUpperCase()
                : user.username[0].toUpperCase(),
          ),
        ),
        title: Text(user.fullName),
        subtitle: Text(user.username),
        trailing: Chip(
          label: Text(roleLabel,
              style: TextStyle(color: roleColor, fontSize: 11)),
          side: BorderSide(color: roleColor.withValues(alpha: 0.4)),
          backgroundColor: roleColor.withValues(alpha: 0.08),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}