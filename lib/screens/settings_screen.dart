import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings screen for managing relays and app preferences
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(Signer.activePubkeyProvider);
    final profile = ref.watch(Signer.activeProfileProvider(LocalSource()));

    // Redirect to auth if not signed in
    if (pubkey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileSection(context, profile),
            const SizedBox(height: 24),

            // Relay Settings Section
            _buildRelaySection(context),
            const SizedBox(height: 24),

            // App Settings Section
            _buildAppSection(context),
            const SizedBox(height: 24),

            // About Section
            _buildAboutSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, Profile? profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile != null) ...[
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text(profile.name ?? 'Anonymous'),
                subtitle: Text(profile.npub),
                contentPadding: EdgeInsets.zero,
              ),
              if (profile.about?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: Text(
                    profile.about!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelaySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_sync,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Relays',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RelayManagerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: const Text('Light/Dark mode'),
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (value) {
                  // TODO: Implement theme switching
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme switching coming soon!')),
                  );
                },
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Push notifications for events'),
              trailing: Switch(
                value: true, // TODO: Connect to actual setting
                onChanged: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification settings coming soon!')),
                  );
                },
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'About NostrCal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('NostrCal'),
              subtitle: const Text('Decentralized calendar on Nostr\nVersion 1.0.0'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Powered by Purplestack'),
              subtitle: const Text('Built with Flutter and Nostr'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Learn more at purplestack.io'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for managing relay connections
class _RelayManagerWidget extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relayController = useTextEditingController();
    final storage = ref.watch(storageNotifierProvider.notifier);
    final currentConfig = storage.config;
    
    // Initialize relays from current configuration
    final relays = useState<List<String>>(
      currentConfig.relayGroups['default']?.toList() ?? [
        'wss://relay.damus.io',
        'wss://relay.primal.net',
        'wss://nos.lol',
      ],
    );

    // Load saved relays from SharedPreferences on widget initialization
    useEffect(() {
      _loadSavedRelays().then((savedRelays) {
        if (savedRelays.isNotEmpty) {
          relays.value = savedRelays;
          _updateStorageConfig(ref, savedRelays);
        }
      });
      return null;
    }, []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add new relay
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: relayController,
                decoration: const InputDecoration(
                  labelText: 'Add Relay',
                  hintText: 'wss://relay.example.com',
                  prefixIcon: Icon(Icons.add_link),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => _addRelay(context, ref, relays, relayController, value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addRelay(context, ref, relays, relayController, relayController.text),
              icon: const Icon(Icons.add),
              tooltip: 'Add Relay',
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Current relays list
        Text(
          'Current Relays (${relays.value.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        
        if (relays.value.isEmpty)
          const ListTile(
            leading: Icon(Icons.warning),
            title: Text('No relays configured'),
            subtitle: Text('Add at least one relay to sync your calendar'),
          )
        else
          ...relays.value.asMap().entries.map((entry) {
            final index = entry.key;
            final relay = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.cloud_sync,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(relay),
                subtitle: Text(_getRelayStatus(relay)),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleRelayAction(
                    context, 
                    ref,
                    relays, 
                    index, 
                    relay, 
                    action,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'test',
                      child: Row(
                        children: [
                          Icon(Icons.speed),
                          SizedBox(width: 8),
                          Text('Test Connection'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 8),
                          Text('Remove'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        
        // Action buttons
        if (relays.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _resetToDefaults(context, ref, relays),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset to Defaults'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _saveRelays(context, relays.value),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<List<String>> _loadSavedRelays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('user_relays') ?? [];
    } catch (e) {
      debugPrint('Failed to load saved relays: $e');
      return [];
    }
  }

  Future<void> _saveRelays(BuildContext context, List<String> relays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_relays', relays);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relay configuration saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save relays: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save relay configuration: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _updateStorageConfig(WidgetRef ref, List<String> relays) {
    final storage = ref.read(storageNotifierProvider.notifier);
    final currentConfig = storage.config;
    
    // Create new configuration with updated relays
    final newConfig = StorageConfiguration(
      databasePath: currentConfig.databasePath,
      keepSignatures: currentConfig.keepSignatures,
      skipVerification: currentConfig.skipVerification,
      relayGroups: {
        ...currentConfig.relayGroups,
        'default': relays.toSet(),
      },
      defaultRelayGroup: currentConfig.defaultRelayGroup,
      defaultQuerySource: currentConfig.defaultQuerySource,
      idleTimeout: currentConfig.idleTimeout,
      responseTimeout: currentConfig.responseTimeout,
      streamingBufferWindow: currentConfig.streamingBufferWindow,
      keepMaxModels: currentConfig.keepMaxModels,
    );

    // Update the storage configuration
    storage.config = newConfig;
  }

  Future<void> _addRelay(BuildContext context, WidgetRef ref, ValueNotifier<List<String>> relays, TextEditingController controller, String relay) async {
    final trimmedRelay = relay.trim();
    if (trimmedRelay.isEmpty) return;
    
    String finalRelay = trimmedRelay;
    if (!trimmedRelay.startsWith('wss://') && !trimmedRelay.startsWith('ws://')) {
      // Auto-add wss:// prefix
      finalRelay = 'wss://$trimmedRelay';
    }
    
    if (!relays.value.contains(finalRelay)) {
      final newRelays = [...relays.value, finalRelay];
      relays.value = newRelays;
      controller.clear();
      
      // Update storage configuration immediately
      _updateStorageConfig(ref, newRelays);
      
      // Save to persistent storage
      await _saveRelays(context, newRelays);
    }
  }

  Future<void> _handleRelayAction(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<List<String>> relays,
    int index,
    String relay,
    String action,
  ) async {
    switch (action) {
      case 'test':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Testing connection to $relay...')),
        );
        // TODO: Implement actual relay connection test
        break;
      case 'remove':
        final newRelays = List<String>.from(relays.value)..removeAt(index);
        relays.value = newRelays;
        
        // Update storage configuration immediately
        _updateStorageConfig(ref, newRelays);
        
        // Save to persistent storage
        await _saveRelays(context, newRelays);
        break;
    }
  }

  Future<void> _resetToDefaults(BuildContext context, WidgetRef ref, ValueNotifier<List<String>> relays) async {
    const defaultRelays = [
      'wss://relay.damus.io',
      'wss://relay.primal.net',
      'wss://nos.lol',
    ];
    
    relays.value = defaultRelays;
    
    // Update storage configuration immediately
    _updateStorageConfig(ref, defaultRelays);
    
    // Save to persistent storage
    await _saveRelays(context, defaultRelays);
  }

  String _getRelayStatus(String relay) {
    // TODO: Implement actual relay status checking
    return 'Connected'; // Placeholder
  }
}