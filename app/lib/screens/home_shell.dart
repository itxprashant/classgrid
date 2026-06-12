import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../storage/attendance_store.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_drawer.dart';
import '../widgets/profile_button.dart';
import 'attendance_screen.dart';
import 'cgpa_calculator_screen.dart';
import 'calendar_screen.dart';
import 'courses_screen.dart';
import 'about_screen.dart';
import 'empty_halls_screen.dart';
import 'plan_screen.dart';
import 'rooms_screen.dart';
import 'settings_screen.dart';

/// Top-level navigation shell: bottom nav over an IndexedStack so each tab keeps
/// its scroll position and state. App bar hosts the wordmark + profile/login.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  PlannerStore? _planner;
  AttendanceStore? _attendance;

  static const _titles = ['Calendar', 'Plan', 'Courses', 'Rooms'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final planner = context.read<PlannerStore>();
    final attendance = context.read<AttendanceStore>();
    if (_planner != planner) {
      _planner?.removeListener(_onPlannerChanged);
      _planner = planner;
      _planner!.addListener(_onPlannerChanged);
    }
    if (_attendance != attendance) {
      _attendance?.removeListener(_onAttendanceChanged);
      _attendance = attendance;
      _attendance!.addListener(_onAttendanceChanged);
    }
  }

  @override
  void dispose() {
    _planner?.removeListener(_onPlannerChanged);
    _attendance?.removeListener(_onAttendanceChanged);
    super.dispose();
  }

  void _onPlannerChanged() {
    final planner = _planner;
    final attendance = _attendance;
    if (planner == null || attendance == null || !planner.planReady) return;
    attendance.onPlannerChanged(
      courses: planner.selectedCourses,
      timetableData: planner.timetableData,
    );
  }

  void _onAttendanceChanged() {
    final target = _attendance?.consumePendingNav();
    if (target == null) return;
    _openAttendance(
      courseCode: target.courseCode,
      sessionKind: target.sessionKind,
      date: target.date,
    );
  }

  void _openEmptyHalls() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EmptyHallsScreen()),
    );
  }

  void _openAttendance({
    String? courseCode,
    String? sessionKind,
    String? date,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(
          initialCourseCode: courseCode,
          initialSessionKind: sessionKind,
          initialDate: date,
        ),
      ),
    );
  }

  void _openCgpaCalculator() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CgpaCalculatorScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Scaffold(
      drawer: AppDrawer(
        selectedIndex: _index,
        onTabSelected: (i) => setState(() => _index = i),
        onOpenEmptyHalls: _openEmptyHalls,
        onOpenAttendance: () => _openAttendance(),
        onOpenCgpaCalculator: _openCgpaCalculator,
        onOpenSettings: _openSettings,
        onOpenAbout: _openAbout,
      ),
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('ClassGrid', style: AppText.serif(size: T.fs21, weight: FontWeight.w600, color: T.ink)),
            const SizedBox(width: 8),
            Text('/ ${_titles[_index].toLowerCase()}',
                style: AppText.mono(size: T.fs12, color: T.ink3)),
          ],
        ),
        actions: const [ProfileButton()],
      ),
      body: Material(
        color: T.paper,
        child: IndexedStack(
          index: _index,
          children: const [
            CalendarScreen(),
            PlanScreen(),
            CoursesScreen(),
            RoomsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Plan'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Courses'),
          NavigationDestination(
              icon: Icon(Icons.domain_outlined),
              selectedIcon: Icon(Icons.domain),
              label: 'Rooms'),
        ],
      ),
    );
  }
}
