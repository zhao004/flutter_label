import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:window_manager/window_manager.dart';

import 'app/controllers/app_settings_controller.dart';
import 'app/database/database.dart';
import 'app/routes/app_pages.dart';
import 'app/services/app_run_log_service.dart';
import 'app/theme/fluent_design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  if (!Get.isRegistered<AppDatabase>()) {
    Get.put<AppDatabase>(AppDatabase(), permanent: true);
  }
  if (!Get.isRegistered<AppRunLogService>()) {
    Get.put<AppRunLogService>(const AppRunLogService(), permanent: true);
  }
  ensureAppSettingsController();
  runApp(ToastificationWrapper(child: const FluentLabelApp()));
}

class FluentLabelApp extends StatefulWidget {
  const FluentLabelApp({super.key});

  @override
  State<FluentLabelApp> createState() => _FluentLabelAppState();
}

class _FluentLabelAppState extends State<FluentLabelApp> {
  @override
  void initState() {
    super.initState();
    _configureGetNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'YOLO 标注工具',
      debugShowCheckedModeBanner: false,
      theme: FluentDesignTokens.lightTheme(),
      darkTheme: FluentDesignTokens.darkTheme(),
      themeMode: ThemeMode.system,
      navigatorKey: Get.key,
      initialRoute: AppPages.initial,
      onGenerateRoute: _generateGetRoute,
      onGenerateInitialRoutes: (routeName) => [
        _generateGetRoute(RouteSettings(name: routeName)),
      ],
      navigatorObservers: [GetObserver(null, Get.routing)],
      builder: FluentDesignTokens.materialCompatibilityBuilder,
    );
  }
}

void _configureGetNavigation() {
  Get.config(
    defaultTransition: Transition.noTransition,
    defaultDurationTransition: Duration.zero,
  );
}

Route<dynamic> _generateGetRoute(RouteSettings settings) {
  final page = _findGetPage(settings.name);
  return GetPageRoute<dynamic>(
    settings: RouteSettings(name: page.name, arguments: settings.arguments),
    page: page.page,
    binding: page.binding,
    bindings: page.bindings,
    transition: page.transition,
    transitionDuration: page.transitionDuration ?? Duration.zero,
    curve: page.curve,
    opaque: page.opaque,
    fullscreenDialog: page.fullscreenDialog,
    maintainState: page.maintainState,
    popGesture: page.popGesture,
    customTransition: page.customTransition,
    middlewares: page.middlewares,
  );
}

GetPage<dynamic> _findGetPage(String? rawRouteName) {
  final routeName = _normalizeRouteName(rawRouteName);
  for (final page in AppPages.routes) {
    if (page.name == routeName) {
      return page;
    }
  }
  return AppPages.routes.firstWhere(
    (page) => page.name == AppPages.initial,
    orElse: () => AppPages.routes.first,
  );
}

String _normalizeRouteName(String? rawRouteName) {
  final routeName = rawRouteName?.trim();
  if (routeName == null || routeName.isEmpty || routeName == '/') {
    return AppPages.initial;
  }
  return Uri.tryParse(routeName)?.path ?? routeName;
}

Future<void> _configureDesktopWindow() async {
  if (kIsWeb || _isFlutterTestBinding()) {
    return;
  }
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1440, 960),
    minimumSize: Size(1180, 760),
    center: true,
    backgroundColor: FluentDesignTokens.titleBarBackground,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    title: 'YOLO 图片标注工具',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

bool _isFlutterTestBinding() {
  final bindingType = WidgetsBinding.instance.runtimeType.toString();
  return bindingType.contains('TestWidgetsFlutterBinding');
}
