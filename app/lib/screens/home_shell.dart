import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../storage/attendance_store.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_navigation.dart';
import '../widgets/profile_button.dart';
import 'attendance_screen.dart';
import 'cgpa_calculator_screen.dart';
import 'calendar_screen.dart';
import 'courses_screen.dart';
import 'about_screen.dart';
import 'empty_halls_screen.dart';
import 'feedback_screen.dart';
import 'plan_screen.dart';
import 'prof_explorer_screen.dart';
import 'student_explorer_screen.dart';
import 'rooms_screen.dart';
import 'settings_screen.dart';

/// Top-level navigation shell: bottom nav over an IndexedStack so each tab keeps
/// its scroll position and state. App bar hosts the wordmark + profile/login.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  String? _drawerRoute;
  PlannerStore? _planner;
  AttendanceStore? _attendance;

  static const _titles = ['Calendar', 'Plan', 'Courses', 'Rooms'];

  static const _tabScreens = [
    CalendarScreen(),
    PlanScreen(),
    CoursesScreen(),
    RoomsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Debounced PUT can be lost if the process dies before 800ms — flush when
    // the OS backgrounds or stops the app.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _planner?.flushPendingSave();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _planner?.flushPendingSave();
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

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _drawerRoute = null;
    });
  }

  void _goToPlanTab() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _index = 1;
      _drawerRoute = null;
    });
  }

  void _openEmptyHalls() {
    pushAppRoute<void>(context, const EmptyHallsScreen());
  }

  void _openAttendance({
    String? courseCode,
    String? sessionKind,
    String? date,
  }) {
    setState(() => _drawerRoute = AppDrawerRoute.attendance);
    pushAppRoute<void>(
      context,
      AttendanceScreen(
        initialCourseCode: courseCode,
        initialSessionKind: sessionKind,
        initialDate: date,
        onGoToPlan: _goToPlanTab,
      ),
    ).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  void _openCgpaCalculator() {
    setState(() => _drawerRoute = AppDrawerRoute.cgpa);
    pushAppRoute<void>(
      context,
      CgpaCalculatorScreen(onGoToPlan: _goToPlanTab),
    ).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  void _openProfExplorer() {
    setState(() => _drawerRoute = AppDrawerRoute.profExplorer);
    pushAppRoute<void>(context, const ProfExplorerScreen()).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  void _openStudentExplorer() {
    setState(() => _drawerRoute = AppDrawerRoute.studentExplorer);
    pushAppRoute<void>(context, const StudentExplorerScreen()).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  void _openSettings() {
    setState(() => _drawerRoute = AppDrawerRoute.settings);
    pushAppRoute<void>(context, const SettingsScreen()).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  void _openAbout() {
    setState(() => _drawerRoute = AppDrawerRoute.about);
    pushAppRoute<void>(context, const AboutScreen()).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  void _openFeedback() {
    setState(() => _drawerRoute = AppDrawerRoute.feedback);
    pushAppRoute<void>(context, const FeedbackScreen()).then((_) {
      if (mounted) setState(() => _drawerRoute = null);
    });
  }

  Future<void> _startLoginFromDrawer() async {
    final auth = context.read<AuthProvider>();
    final opened = await auth.startBrowserLogin();
    if (!mounted) return;
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in on ClassGrid in your browser, then return here.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final fadeDuration = disableAnimations ? Duration.zero : T.tBase;

    return Scaffold(
      drawer: AppDrawer(
        selectedIndex: _index,
        selectedDrawerRoute: _drawerRoute,
        onTabSelected: _selectTab,
        onOpenEmptyHalls: _openEmptyHalls,
        onOpenAttendance: () => _openAttendance(),
        onOpenCgpaCalculator: _openCgpaCalculator,
        onOpenProfExplorer: _openProfExplorer,
        onOpenStudentExplorer: _openStudentExplorer,
        onOpenSettings: _openSettings,
        onOpenFeedback: _openFeedback,
        onOpenAbout: _openAbout,
        onLoginTap: _startLoginFromDrawer,
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
          children: List.generate(_tabScreens.length, (i) {
            return AnimatedOpacity(
              key: ValueKey<int>(i),
              opacity: _index == i ? 1.0 : 0.0,
              duration: fadeDuration,
              curve: T.easeOut,
              child: IgnorePointer(
                ignoring: _index != i,
                child: _tabScreens[i],
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
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
