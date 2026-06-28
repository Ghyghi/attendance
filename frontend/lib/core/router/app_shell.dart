import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/attendance/presentation/attendance_histroy_screen.dart';
import '../../features/attendance/presentation/attendance_records_screen.dart';
import '../../features/attendance/presentation/session_list_screen.dart';
import '../../features/attendance/presentation/submit_attendance_screen.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/face_recognition/presentation/enroll_face_screen.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/schools/presentation/classroom_list_screen.dart';
import '../../features/schools/presentation/student_classrooms_screen.dart';
import '../../features/common/presentation/settings_screen.dart';
import '../../features/users/presentation/user_list_screen.dart';

/// One tab's worth of nav-bar metadata + the screen it shows.
class _ShellTab {
  const _ShellTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
    this.showsUnreadBadge = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  /// True only for the Notifications tab. Kept as an explicit flag rather
  /// than checking `screen is NotificationsScreen` at the call site — the
  /// badge logic in build() shouldn't need to know which concrete screen
  /// type corresponds to "the notifications one".
  final bool showsUnreadBadge;
}

/// Bottom-nav shell wrapping every authenticated screen. Tabs are
/// computed from [user.role] — admin, teacher, and student each see a
/// different tab bar reflecting what they are permitted to do server-side.
///
/// The logout button has been moved from the AppBar into the Settings tab
/// so it is not one accidental tap away during normal use.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.user});

  final User user;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  List<_ShellTab> _tabsForRole(UserRole role) {
    // Settings tab is shown for every role — it contains the logout
    // button and change-password sheet.
    const settingsTab = _ShellTab(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
      screen: SettingsScreen(),
    );

    const notificationsTab = _ShellTab(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      label: 'Notifications',
      screen: NotificationsScreen(),
      showsUnreadBadge: true,
    );

    switch (role) {
      case UserRole.admin:
        return const [
          _ShellTab(
            icon: Icons.class_outlined,
            activeIcon: Icons.class_,
            label: 'Classrooms',
            screen: ClassroomListScreen(),
          ),
          _ShellTab(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Users',
            screen: UserListScreen(),
          ),
          _ShellTab(
            icon: Icons.face_outlined,
            activeIcon: Icons.face,
            label: 'Enroll Face',
            screen: EnrollFaceScreen(),
          ),
          notificationsTab,
          settingsTab,
        ];

      case UserRole.teacher:
        return const [
          _ShellTab(
            icon: Icons.qr_code_outlined,
            activeIcon: Icons.qr_code,
            label: 'Sessions',
            screen: SessionListScreen(),
          ),
          _ShellTab(
            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check,
            label: 'Records',
            screen: AttendanceRecordsScreen(),
          ),
          _ShellTab(
            icon: Icons.class_outlined,
            activeIcon: Icons.class_,
            label: 'Classrooms',
            screen: ClassroomListScreen(),
          ),
          notificationsTab,
          settingsTab,
        ];

      case UserRole.student:
        return const [
          _ShellTab(
            icon: Icons.qr_code_scanner,
            activeIcon: Icons.qr_code_scanner,
            label: 'Submit',
            screen: SubmitAttendanceScreen(),
          ),
          _ShellTab(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            label: 'History',
            screen: AttendanceHistoryScreen(),
          ),
          _ShellTab(
            icon: Icons.class_outlined,
            activeIcon: Icons.class_,
            label: 'My Classes',
            screen: StudentClassroomsScreen(),
          ),
          notificationsTab,
          settingsTab,
        ];
    }
  }

  /// Wraps [child] with a small unread-count badge when [show] is true
  /// and the count is > 0. Caps the displayed number at 99+ so a runaway
  /// count doesn't blow out the nav bar's layout.
  Widget _withUnreadBadge(Widget child, bool show, int unreadCount) {
    if (!show || unreadCount <= 0) return child;
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();
    return Badge(
      label: Text(label),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsForRole(widget.user.role);
    // Guard: if a tab was removed between rebuilds, reset to 0.
    final safeIndex = _index < tabs.length ? _index : 0;
    final activeTab = tabs[safeIndex];

    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(activeTab.label),
      ),
      body: IndexedStack(
        index: safeIndex,
        children: [for (final tab in tabs) tab.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Jumping into the Notifications tab is a good moment to get an
          // immediate badge refresh rather than waiting for the next
          // periodic tick — the user is about to read (and likely mark
          // read) what the badge is counting.
          if (tabs[i].showsUnreadBadge) {
            ref.invalidate(unreadCountProvider);
          }
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: _withUnreadBadge(
                Icon(tab.icon),
                tab.showsUnreadBadge,
                unreadCount,
              ),
              selectedIcon: _withUnreadBadge(
                Icon(tab.activeIcon),
                tab.showsUnreadBadge,
                unreadCount,
              ),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}