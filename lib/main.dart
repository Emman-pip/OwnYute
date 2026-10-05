import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_controller.dart';
import 'core/app_logo.dart';
import 'core/app_themes.dart';
import 'core/crash_diagnostics.dart';
import 'features/search/search_page.dart';
import 'features/queue/queue_page.dart';
import 'features/library/library_page.dart';
import 'features/player/player_widgets.dart';
import 'features/settings/settings_page.dart';

final appProvider = Provider<AppController>((ref) {
  final app = AppController();
  ref.onDispose(app.dispose);
  app.initialize();
  return app;
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    unawaited(CrashDiagnostics.recordDart(details.exception, details.stack));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(CrashDiagnostics.recordDart(error, stack));
    return false;
  };
  runApp(const ProviderScope(child: OwnYuteApp()));
}

class OwnYuteApp extends ConsumerWidget {
  const OwnYuteApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'OwnYute',
        themeMode: app.themeMode,
        theme: AppThemes.light(app.themeChoice),
        darkTheme: AppThemes.dark(app.themeChoice),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 700;
        final body = [
          SearchPage(app: app, onQueue: () => setState(() => page = 1)),
          QueuePage(app: app),
          LibraryPage(app: app),
        ][page];
        return Scaffold(
          appBar: AppBar(
            title: const AppBrandTitle(),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsPage(app: app),
                  ),
                ),
              ),
              if (app.busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: page,
                  onDestinationSelected: (value) =>
                      setState(() => page = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.search),
                      label: Text('Search'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.download),
                      label: Text('Queue'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.library_music),
                      label: Text('Library'),
                    ),
                  ],
                ),
              Expanded(
                child: Column(
                  children: [
                    if (app.error != null)
                      MaterialBanner(
                        content: Text(app.error!),
                        actions: [
                          TextButton(
                            onPressed: () {
                              app.clearError();
                            },
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: body,
                        ),
                      ),
                    ),
                    MiniPlayer(app: app),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: (value) =>
                      setState(() => page = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.download),
                      label: 'Queue',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.library_music),
                      label: 'Library',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
