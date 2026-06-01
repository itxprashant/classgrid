import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/calendar_events_api.dart';
import 'api/occupied_rooms_api.dart';
import 'api/personal_events_api.dart';
import 'api/courses_api.dart';
import 'api/planner_api.dart';
import 'api/reminders_api.dart';
import 'state/auth_provider.dart';
import 'state/catalog_provider.dart';
import 'state/planner_store.dart';
import 'storage/local_store.dart';
import 'storage/reminder_store.dart';
import 'theme/app_theme.dart';
import 'notifications/class_notification_service.dart';
import 'screens/home_shell.dart';
import 'widgets/auth_deep_link_listener.dart';
import 'widgets/version_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GoogleFonts.pendingFonts([
    GoogleFonts.inter(),
    GoogleFonts.fraunces(),
    GoogleFonts.ibmPlexMono(),
  ]);

  await ClassNotificationService.instance.init();

  final apiClient = await ApiClient.create();
  final localStore = await LocalStore.create();
  final prefs = localStore.sharedPreferences;
  final reminderStore = ReminderStore(
    prefs,
    ClassNotificationService.instance,
    remindersApi: RemindersApi(apiClient),
  );
  await reminderStore.load();

  runApp(ClassGridApp(
    apiClient: apiClient,
    localStore: localStore,
    reminderStore: reminderStore,
  ));
}

class ClassGridApp extends StatelessWidget {
  const ClassGridApp({
    super.key,
    required this.apiClient,
    required this.localStore,
    required this.reminderStore,
  });

  final ApiClient apiClient;
  final LocalStore localStore;
  final ReminderStore reminderStore;

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogProvider(apiClient, localStore);
    final auth = AuthProvider(apiClient);
    final planner = PlannerStore(
      plannerApi: PlannerApi(apiClient),
      store: localStore,
      catalog: catalog,
    );

    planner.initGuest();
    catalog.load();
    auth.addListener(() {
      if (!auth.loading) {
        planner.onUserChanged(auth.user);
        reminderStore.onAuthChanged(isLoggedIn: auth.isLoggedIn);
      }
    });
    auth.init();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<LocalStore>.value(value: localStore),
        Provider<CalendarEventsApi>.value(value: CalendarEventsApi(apiClient)),
        Provider<PersonalEventsApi>.value(value: PersonalEventsApi(apiClient)),
        Provider<OccupiedRoomsApi>.value(value: OccupiedRoomsApi(apiClient)),
        Provider<CoursesApi>.value(value: CoursesApi(apiClient)),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<PlannerStore>.value(value: planner),
        ChangeNotifierProvider<ReminderStore>.value(value: reminderStore),
      ],
      child: AuthDeepLinkListener(
        child: MaterialApp(
          title: 'ClassGrid',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          themeMode: ThemeMode.light,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(platformBrightness: Brightness.light),
              child: DefaultTextStyle(
                style: AppText.sans(),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: VersionGate(
            apiClient: apiClient,
            child: const HomeShell(),
          ),
        ),
      ),
    );
  }
}
