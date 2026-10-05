import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_controller.dart';
import '../../core/crash_diagnostics.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;

  Future<void> _copyDiagnostics(BuildContext context) async {
    final report = await CrashDiagnostics.report();
    await Clipboard.setData(ClipboardData(text: report));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Android diagnostics copied.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (app.error != null)
            ListTile(
              title: Text(app.error!),
              trailing: TextButton(
                onPressed: app.clearError,
                child: const Text('Dismiss'),
              ),
            ),
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in AppThemeChoice.values)
                ChoiceChip(
                  label: Text(switch (mode) {
                    AppThemeChoice.system => 'System',
                    AppThemeChoice.light => 'Light',
                    AppThemeChoice.dark => 'Dark',
                    AppThemeChoice.pastelBlue => 'Pastel Blue',
                    AppThemeChoice.pastelPink => 'Pastel Pink',
                  }),
                  selected: app.themeChoice == mode,
                  onSelected: (_) => app.setThemeChoice(mode),
                ),
            ],
          ),
          SwitchListTile(
            title: const Text('Animated player artwork'),
            subtitle: const Text('Gentle motion while music is playing'),
            value: app.playerAnimationEnabled,
            onChanged: app.setPlayerAnimationEnabled,
          ),
          const SizedBox(height: 24),
          Text('YouTube tools', style: Theme.of(context).textTheme.titleLarge),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Build and crash report'),
              subtitle: FutureBuilder<String>(
                future: CrashDiagnostics.report(),
                builder: (context, snapshot) => Text(
                  snapshot.data?.split('\n').first ??
                      'Loading build information…',
                ),
              ),
              trailing: IconButton(
                tooltip: 'Copy diagnostics',
                icon: const Icon(Icons.copy),
                onPressed: () => _copyDiagnostics(context),
              ),
            ),
          ListenableBuilder(
            listenable: app.tools,
            builder: (context, _) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update),
                  title: const Text('yt-dlp nightly'),
                  subtitle: Text(
                    app.tools.updating
                        ? 'Checking for an update…'
                        : app.tools.lastError ??
                              (app.tools.version == null
                                  ? 'Checks before the first YouTube action each day'
                                  : 'Available version: ${app.tools.version}'),
                  ),
                  trailing: app.tools.updating
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: () => app.tools.check(force: true),
                          child: const Text('Check now'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Downloads', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Default destination'),
            subtitle: Text(app.destinationLabel ?? 'No folder chosen'),
            onTap: app.chooseDestination,
          ),
          const SizedBox(height: 24),
          Text('Music folders', style: Theme.of(context).textTheme.titleLarge),
          ...app.importedFolders.map(
            (folder) => ListTile(
              title: Text(
                app.importedFolderLabels[folder] ?? folder,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Stop scanning this folder',
                icon: const Icon(Icons.close),
                onPressed: () => app.stopScanningFolder(folder),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: app.importFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Import folder'),
              ),
              OutlinedButton.icon(
                onPressed: app.refreshLibrary,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh library'),
              ),
              OutlinedButton.icon(
                onPressed: app.importFiles,
                icon: const Icon(Icons.audio_file_outlined),
                label: const Text('Import audio files'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
