import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/profile_button.dart';
import 'calendar_screen.dart';
import 'courses_screen.dart';
import 'empty_halls_screen.dart';
import 'plan_screen.dart';

/// Top-level navigation shell: bottom nav over an IndexedStack so each tab keeps
/// its scroll position and state. App bar hosts the wordmark + profile/login.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Plan', 'Courses', 'Empty halls', 'Calendar'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('ClassGrid', style: AppText.serif(size: T.fs21, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('/ ${_titles[_index].toLowerCase()}',
                style: AppText.mono(size: T.fs12, color: T.ink3)),
          ],
        ),
        actions: const [ProfileButton()],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          PlanScreen(),
          CoursesScreen(),
          EmptyHallsScreen(),
          CalendarScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Plan'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Courses'),
          NavigationDestination(
              icon: Icon(Icons.meeting_room_outlined),
              selectedIcon: Icon(Icons.meeting_room),
              label: 'Halls'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
        ],
      ),
    );
  }
}
