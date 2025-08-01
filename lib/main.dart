import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:purplebase/purplebase.dart';
import 'package:amber_signer/amber_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostrcal/router.dart';
import 'package:nostrcal/theme.dart';
import 'models/models.dart';

/// Provider for the Amber signer instance
final amberSignerProvider = Provider<AmberSigner>(AmberSigner.new);

void main() {
  runZonedGuarded(() {
    runApp(
      ProviderScope(
        overrides: [
          storageNotifierProvider.overrideWith(
            (ref) => PurplebaseStorageNotifier(ref),
          ),
        ],
        child: const NostrcalApp(),
      ),
    );
  }, errorHandler);

  FlutterError.onError = (details) {
    // Prevents debugger stopping multiple times
    FlutterError.dumpErrorToConsole(details);
    errorHandler(details.exception, details.stack);
  };
}

class NostrcalApp extends ConsumerWidget {
  const NostrcalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = 'NostrCal';
    final theme = ref.watch(themeProvider);

    return switch (ref.watch(appInitializationProvider)) {
      AsyncLoading() => MaterialApp(
        title: title,
        theme: theme,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
      ),
      AsyncError(:final error) => MaterialApp(
        title: title,
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Initialization Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
      _ => MaterialApp.router(
        title: title,
        theme: theme,
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
        builder: (_, child) => child!,
      ),
    };
  }
}

class NostrcalHome extends StatelessWidget {
  const NostrcalHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: const Icon(
                  Icons.calendar_month,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'NostrCal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Decentralized calendar on Nostr',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void errorHandler(Object exception, StackTrace? stack) {
  // TODO: Implement proper error handling
  debugPrint('Error: $exception');
  debugPrint('Stack trace: $stack');
}

final appInitializationProvider = FutureProvider<void>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  
  // Load saved relays from SharedPreferences
  Set<String> defaultRelays = {
    'wss://relay.damus.io',
    'wss://relay.primal.net',
    'wss://nos.lol',
  };
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedRelays = prefs.getStringList('user_relays');
    if (savedRelays != null && savedRelays.isNotEmpty) {
      defaultRelays = savedRelays.toSet();
    }
  } catch (e) {
    debugPrint('Failed to load saved relays during initialization: $e');
  }
  
  await ref.read(
    initializationProvider(
      StorageConfiguration(
        databasePath: path.join(dir.path, 'nostrcal.db'),
        relayGroups: {
          'default': defaultRelays,
        },
        defaultRelayGroup: 'default',
      ),
    ).future,
  );

  // Register custom NostrCal models
  // Note: CalendarEventRSVP (31925) is already registered in the models package
  
  Model.register(
    kind: 31926,
    constructor: CalendarAvailability.fromMap,
    partialConstructor: (map) => PartialCalendarAvailability.fromMap(map),
  );

  Model.register(
    kind: 31927,
    constructor: CalendarAvailabilityBlock.fromMap,
    partialConstructor: (map) => PartialCalendarAvailabilityBlock.fromMap(map),
  );
});
