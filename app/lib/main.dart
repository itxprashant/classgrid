import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/attendance_api.dart';
import 'api/calendar_events_api.dart';
import 'api/occupied_rooms_api.dart';
import 'api/personal_events_api.dart';
import 'api/courses_api.dart';
import 'api/history_api.dart';
import 'api/course_policy_api.dart';
import 'api/feedback_api.dart';
import 'api/reports_api.dart';
import 'api/planner_api.dart';
import 'api/reminders_api.dart';
import 'api/fcm_api.dart';
import 'state/auth_provider.dart';
import 'state/catalog_provider.dart';
import 'state/explorer_catalog_provider.dart';
import 'state/semester_data_provider.dart';
import 'state/planner_store.dart';
import 'state/theme_controller.dart';
import 'storage/attendance_store.dart';
import 'storage/local_store.dart';
import 'storage/reminder_store.dart';
import 'storage/update_release_store.dart';
import 'theme/app_palette_scope.dart';
import 'theme/app_theme.dart';
import 'notifications/class_notification_service.dart';
import 'notifications/fcm_service.dart';
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

  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      await FcmService.instance.init(
        apiClient,
        fcmApi: FcmApi(apiClient),
      );
    } catch (e) {
      debugPrint('[FCM] init failed: $e');
    }
  }

  final localStore = await LocalStore.create();
  final prefs = localStore.sharedPreferences;
  final updateReleaseStore = UpdateReleaseStore(prefs);
  final reminderStore = ReminderStore(
    prefs,
    ClassNotificationService.instance,
    remindersApi: RemindersApi(apiClient),
  );
  await reminderStore.load();

  final attendanceStore = AttendanceStore(
    prefs,
    ClassNotificationService.instance,
    attendanceApi: AttendanceApi(apiClient),
  );
  await attendanceStore.load();
  ClassNotificationService.instance.onNotificationTap =
      attendanceStore.handleNotificationPayload;

  final themeController = ThemeController(prefs);

  runApp(ClassGridApp(
    apiClient: apiClient,
    localStore: localStore,
    updateReleaseStore: updateReleaseStore,
    reminderStore: reminderStore,
    attendanceStore: attendanceStore,
    themeController: themeController,
  ));
}

class ClassGridApp extends StatelessWidget {
  const ClassGridApp({
    super.key,
    required this.apiClient,
    required this.localStore,
    required this.updateReleaseStore,
    required this.reminderStore,
    required this.attendanceStore,
    required this.themeController,
  });

  final ApiClient apiClient;
  final LocalStore localStore;
  final UpdateReleaseStore updateReleaseStore;
  final ReminderStore reminderStore;
  final AttendanceStore attendanceStore;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogProvider(apiClient, localStore);
    final explorerCatalog = ExplorerCatalogProvider(apiClient);
    final semesterData = SemesterDataProvider(apiClient, localStore);
    final auth = AuthProvider(apiClient);
    final planner = PlannerStore(
      plannerApi: PlannerApi(apiClient),
      store: localStore,
      catalog: catalog,
    );

    planner.initGuest();
    catalog.load();
    explorerCatalog.load();
    semesterData.load();
    auth.addListener(() {
      if (!auth.loading) {
        planner.onUserChanged(auth.user);
        reminderStore.onAuthChanged(isLoggedIn: auth.isLoggedIn);
        attendanceStore.onAuthChanged(isLoggedIn: auth.isLoggedIn);
        if (Platform.isAndroid) {
          FcmService.instance.onAuthChanged(isLoggedIn: auth.isLoggedIn);
        }
      }
    });
    auth.init();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<LocalStore>.value(value: localStore),
        Provider<UpdateReleaseStore>.value(value: updateReleaseStore),
        Provider<CalendarEventsApi>.value(value: CalendarEventsApi(apiClient)),
        Provider<PersonalEventsApi>.value(value: PersonalEventsApi(apiClient)),
        Provider<OccupiedRoomsApi>.value(value: OccupiedRoomsApi(apiClient)),
        Provider<CoursesApi>.value(value: CoursesApi(apiClient)),
        Provider<HistoryApi>.value(value: HistoryApi(apiClient)),
        Provider<CoursePolicyApi>.value(value: CoursePolicyApi(apiClient)),
        Provider<FeedbackApi>.value(value: FeedbackApi(apiClient)),
        Provider<ReportsApi>.value(value: ReportsApi(apiClient)),
        Provider<PlannerApi>.value(value: PlannerApi(apiClient)),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ChangeNotifierProvider<ExplorerCatalogProvider>.value(value: explorerCatalog),
        ChangeNotifierProvider<SemesterDataProvider>.value(value: semesterData),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<PlannerStore>.value(value: planner),
        ChangeNotifierProvider<ReminderStore>.value(value: reminderStore),
        ChangeNotifierProvider<AttendanceStore>.value(value: attendanceStore),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: AppPaletteScope(
        notifier: themeController,
        child: AuthDeepLinkListener(
          child: Consumer<ThemeController>(
            builder: (context, theme, _) {
              final brightness = theme.palette.brightness;
              return MaterialApp(
                title: 'ClassGrid',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(),
                themeMode:
                    brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(platformBrightness: brightness),
                    child: DefaultTextStyle(
                      style: AppText.sans(),
                      // New key forces the navigator + routes to rebuild so every
                      // widget that reads [T] picks up the active palette.
                      child: KeyedSubtree(
                        key: ValueKey(theme.currentId),
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                home: VersionGate(
                  apiClient: apiClient,
                  releaseStore: updateReleaseStore,
                  child: const HomeShell(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
