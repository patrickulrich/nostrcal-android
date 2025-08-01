import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/profile_avatar.dart';
import '../main.dart';

/// Provider for fetching parent events of RSVPs
final parentEventProvider = FutureProvider.family<Model<dynamic>?, String>((ref, eventAddress) async {
  try {
    final storage = ref.read(storageNotifierProvider.notifier);
    
    // Parse the event address (format: "kind:pubkey:d-identifier")
    final parts = eventAddress.split(':');
    if (parts.length != 3) return null;
    
    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;
    
    // Create a request filter for the specific parent event
    final request = RequestFilter(
      kinds: {kind},
      authors: {parts[1]},
      tags: {
        '#d': {parts[2]},
      },
      limit: 1,
    ).toRequest();
    
    final results = await storage.query(request, source: LocalAndRemoteSource(background: false));
    return results.isNotEmpty ? results.first : null;
  } catch (e) {
    debugPrint('Failed to fetch parent event: $e');
    return null;
  }
});

/// Provider for enriched events that includes RSVPs with their parent event timing
final enrichedEventsProvider = FutureProvider.family<List<EnrichedEvent>, String>((ref, pubkey) async {
  try {
    final storage = ref.read(storageNotifierProvider.notifier);
    
    // Query all event types
    final request = RequestFilter(
      kinds: {31922, 31923, 31925}, // Date-based, time-based, and RSVPs
      authors: {pubkey},
      limit: 100,
    ).toRequest();
    
    final allEvents = await storage.query(request, source: LocalAndRemoteSource(background: false));
    final enrichedEvents = <EnrichedEvent>[];
    
    for (final event in allEvents) {
      if (event is CalendarEventRSVP) {
        // For RSVPs, try to fetch parent event
        final eventAddress = event.eventAddress;
        if (eventAddress != null) {
          try {
            final parentEvent = await ref.read(parentEventProvider(eventAddress).future);
            enrichedEvents.add(EnrichedEvent.rsvp(event, parentEvent));
          } catch (e) {
            // If parent fetch fails, still include the RSVP
            enrichedEvents.add(EnrichedEvent.rsvp(event, null));
          }
        } else {
          enrichedEvents.add(EnrichedEvent.rsvp(event, null));
        }
      } else {
        // Regular calendar events
        enrichedEvents.add(EnrichedEvent.regular(event));
      }
    }
    
    return enrichedEvents;
  } catch (e) {
    debugPrint('Failed to fetch enriched events: $e');
    return [];
  }
});

/// Wrapper class for events with optional parent event information
class EnrichedEvent {
  final dynamic originalEvent;
  final Model<dynamic>? parentEvent;
  final bool isRSVP;
  
  EnrichedEvent.regular(this.originalEvent) : parentEvent = null, isRSVP = false;
  EnrichedEvent.rsvp(this.originalEvent, this.parentEvent) : isRSVP = true;
  
  /// Get the timing information for this event
  DateTime? get startDateTime {
    final event = parentEvent ?? originalEvent;
    if (event == null) return null;
    
    if (event.event.kind == 31922) {
      // Date-based event
      final startDate = event.event.getFirstTagValue('start');
      if (startDate != null) {
        return DateTime.parse('${startDate}T00:00:00');
      }
    } else if (event.event.kind == 31923) {
      // Time-based event
      final startTime = event.event.getFirstTagValue('start');
      if (startTime != null) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(startTime) * 1000);
      }
    }
    
    // Fallback to original event creation time for RSVPs without parent
    if (isRSVP && originalEvent is CalendarEventRSVP) {
      return (originalEvent as CalendarEventRSVP).createdAt;
    }
    
    return null;
  }
  
  DateTime? get endDateTime {
    final event = parentEvent ?? originalEvent;
    if (event == null) return null;
    
    if (event.event.kind == 31922) {
      // Date-based event
      final endDate = event.event.getFirstTagValue('end');
      if (endDate != null) {
        return DateTime.parse('${endDate}T00:00:00');
      }
      // If no end date, return start + 1 day
      final start = startDateTime;
      return start?.add(const Duration(days: 1));
    } else if (event.event.kind == 31923) {
      // Time-based event
      final endTime = event.event.getFirstTagValue('end');
      if (endTime != null) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(endTime) * 1000);
      }
      // If no end time, event is instantaneous
      return startDateTime;
    }
    
    return startDateTime;
  }
  
  /// Check if this event occurs on a specific day
  bool occursOnDay(DateTime day) {
    final start = startDateTime;
    final end = endDateTime;
    
    if (start == null) return false;
    
    if (end == null) {
      return isSameDay(day, start);
    }
    
    return day.isAfter(start.subtract(const Duration(days: 1))) && 
           day.isBefore(end);
  }
}

/// Main calendar screen showing user's events
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ValueNotifier<DateTime> _selectedDay;
  late final ValueNotifier<DateTime> _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = ValueNotifier(now);
    _focusedDay = ValueNotifier(now);
  }

  @override
  void dispose() {
    _selectedDay.dispose();
    _focusedDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = ref.watch(Signer.activePubkeyProvider);
    final profile = ref.watch(Signer.activeProfileProvider(LocalAndRemoteSource()));

    // Redirect to auth if not signed in
    if (pubkey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NostrCal'),
        actions: [
          _buildEventsDiscoveryButton(context),
          _buildCalendarButton(context),
          _buildProfileButton(context, profile),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'availability',
                child: Row(
                  children: [
                    Icon(Icons.schedule),
                    SizedBox(width: 8),
                    Text('Manage Availability'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarWidget(context, pubkey),
          const Divider(height: 1),
          Expanded(
            child: _buildEventsList(context, pubkey),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewEvent(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventsDiscoveryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: IconButton(
        onPressed: () => context.push('/events'),
        icon: const Icon(Icons.people),
        tooltip: 'Discover Events',
      ),
    );
  }

  Widget _buildCalendarButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: IconButton(
        onPressed: () {
          // Already on calendar screen, could refresh or scroll to today
          final now = DateTime.now();
          _selectedDay.value = now;
          _focusedDay.value = now;
        },
        icon: const Icon(Icons.calendar_month),
        tooltip: 'Calendar',
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context, Profile? profile) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
        onPressed: () => _showProfileSheet(context, profile),
        icon: ProfileAvatar(
          profile: profile,
          radius: 16,
        ),
        tooltip: 'Profile',
      ),
    );
  }

  Widget _buildCalendarWidget(BuildContext context, String pubkey) {
    // Use enriched events provider that includes RSVP parent event timing
    final enrichedEventsState = ref.watch(enrichedEventsProvider(pubkey));

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ValueListenableBuilder<DateTime>(
          valueListenable: _focusedDay,
          builder: (context, focusedDay, _) {
            return ValueListenableBuilder<DateTime>(
              valueListenable: _selectedDay,
              builder: (context, selectedDay, _) {
                return TableCalendar<dynamic>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: (day) => _getEnrichedEventsForDay(day, enrichedEventsState),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    markerDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    _selectedDay.value = selectedDay;
                    _focusedDay.value = focusedDay;
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay.value = focusedDay;
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, String pubkey) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _selectedDay,
      builder: (context, selectedDay, _) {
        // Use enriched events provider
        final enrichedEventsState = ref.watch(enrichedEventsProvider(pubkey));

        return switch (enrichedEventsState) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          AsyncData() => () {
            final dayEvents = _getEnrichedEventsForDayFull(selectedDay, enrichedEventsState);
            
            if (dayEvents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No events for ${_formatDate(selectedDay)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to create your first event',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: dayEvents.length,
              itemBuilder: (context, index) {
                final enrichedEvent = dayEvents[index];
                return _buildEnrichedEventCard(context, enrichedEvent);
              },
            );
          }(),
          _ => const Center(child: Text('Unknown state')),
        };
      },
    );
  }

  Widget _buildEventCard(BuildContext context, dynamic event) {
    // Check if this is an RSVP event
    if (event is CalendarEventRSVP) {
      return _buildRSVPCard(context, event);
    }
    
    // Handle DateBasedCalendarEvent and TimeBasedCalendarEvent
    final title = event.event.getFirstTagValue('title') ?? 'Untitled Event';
    final description = event.event.content;
    
    String timeInfo = '';
    if (event.runtimeType.toString().contains('DateBased')) {
      final startDate = event.event.getFirstTagValue('start');
      final endDate = event.event.getFirstTagValue('end');
      timeInfo = endDate != null ? '$startDate to $endDate' : startDate ?? '';
    } else {
      // TimeBasedCalendarEvent
      final startTime = event.event.getFirstTagValue('start');
      final endTime = event.event.getFirstTagValue('end');
      if (startTime != null) {
        final start = DateTime.fromMillisecondsSinceEpoch(int.parse(startTime) * 1000);
        timeInfo = _formatTime(start);
        if (endTime != null) {
          final end = DateTime.fromMillisecondsSinceEpoch(int.parse(endTime) * 1000);
          timeInfo += ' - ${_formatTime(end)}';
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.event,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timeInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeInfo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showEventActions(context, event),
        ),
        onTap: () => _viewEventDetails(context, event),
      ),
    );
  }

  List<dynamic> _getEnrichedEventsForDay(DateTime day, AsyncValue<List<EnrichedEvent>> enrichedEventsState) {
    return switch (enrichedEventsState) {
      AsyncData(:final value) => value
          .where((enrichedEvent) => enrichedEvent.occursOnDay(day))
          .map((enrichedEvent) => enrichedEvent.originalEvent)
          .toList(),
      _ => <dynamic>[],
    };
  }

  List<EnrichedEvent> _getEnrichedEventsForDayFull(DateTime day, AsyncValue<List<EnrichedEvent>> enrichedEventsState) {
    return switch (enrichedEventsState) {
      AsyncData(:final value) => value
          .where((enrichedEvent) => enrichedEvent.occursOnDay(day))
          .toList(),
      _ => <EnrichedEvent>[],
    };
  }

  Widget _buildEnrichedEventCard(BuildContext context, EnrichedEvent enrichedEvent) {
    if (enrichedEvent.isRSVP) {
      return _buildRSVPCard(context, enrichedEvent.originalEvent as CalendarEventRSVP);
    } else {
      return _buildEventCard(context, enrichedEvent.originalEvent);
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'availability':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability management coming soon!')),
        );
        break;
      case 'settings':
        context.push('/settings');
        break;
      case 'signout':
        _signOut(context);
        break;
    }
  }

  void _showProfileSheet(BuildContext context, Profile? profile) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                ProfileAvatar(profile: profile, radius: 32),
                const SizedBox(height: 16),
                Text(
                  profile?.name ?? 'Anonymous',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (profile?.about != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile!.about!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _signOut(context);
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewEvent(BuildContext context) {
    context.push('/event/create');
  }

  void _viewEventDetails(BuildContext context, dynamic event) {
    context.push(
      '/event/${event.event.id}',
      extra: {
        'event': event,
        'kind': event.event.kind,
        'pubkey': event.event.pubkey,
        'createdAt': event.event.createdAt,
      },
    );
  }

  void _showEventActions(BuildContext context, dynamic event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Event'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to edit event screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Event'),
            onTap: () {
              Navigator.pop(context);
              _deleteEvent(context, event);
            },
          ),
        ],
      ),
    );
  }

  void _deleteEvent(BuildContext context, dynamic event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement event deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event deletion coming soon!')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await ref.read(amberSignerProvider).signOut();
      if (context.mounted) {
        context.go('/auth');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Widget _buildRSVPCard(BuildContext context, CalendarEventRSVP rsvp) {
    final eventAddress = rsvp.eventAddress;
    if (eventAddress == null) {
      return _buildErrorCard(context, 'Invalid RSVP: Missing parent event address');
    }

    // Watch the parent event
    final parentEventState = ref.watch(parentEventProvider(eventAddress));

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: parentEventState.when(
        data: (parentEvent) {
          if (parentEvent == null) {
            return _buildRSVPCardWithoutParent(context, rsvp, eventAddress);
          }
          return _buildRSVPCardWithParent(context, rsvp, parentEvent);
        },
        loading: () => ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          title: Text(_getRSVPStatusText(rsvp)),
          subtitle: const Text('Loading event details...'),
        ),
        error: (error, stack) => _buildRSVPCardWithoutParent(context, rsvp, eventAddress),
      ),
    );
  }

  Widget _buildRSVPCardWithParent(BuildContext context, CalendarEventRSVP rsvp, Model<dynamic> parentEvent) {
    final title = parentEvent.event.getFirstTagValue('title') ?? 'Untitled Event';
    final description = rsvp.note.isNotEmpty ? rsvp.note : parentEvent.event.content;
    
    // Extract time information from parent event
    String timeInfo = '';
    if (parentEvent.event.kind == 31922) {
      // Date-based event
      final startDate = parentEvent.event.getFirstTagValue('start');
      final endDate = parentEvent.event.getFirstTagValue('end');
      timeInfo = endDate != null ? '$startDate to $endDate' : startDate ?? '';
    } else if (parentEvent.event.kind == 31923) {
      // Time-based event
      final startTime = parentEvent.event.getFirstTagValue('start');
      final endTime = parentEvent.event.getFirstTagValue('end');
      if (startTime != null) {
        final start = DateTime.fromMillisecondsSinceEpoch(int.parse(startTime) * 1000);
        timeInfo = _formatTime(start);
        if (endTime != null) {
          final end = DateTime.fromMillisecondsSinceEpoch(int.parse(endTime) * 1000);
          timeInfo += ' - ${_formatTime(end)}';
        }
      }
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRSVPStatusColor(context, rsvp),
        child: Icon(
          _getRSVPStatusIcon(rsvp),
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getRSVPStatusText(rsvp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _getRSVPStatusColor(context, rsvp),
            ),
          ),
          if (timeInfo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              timeInfo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showRSVPActions(context, rsvp, parentEvent),
      ),
      onTap: () => _viewRSVPDetails(context, rsvp, parentEvent),
    );
  }

  Widget _buildRSVPCardWithoutParent(BuildContext context, CalendarEventRSVP rsvp, String eventAddress) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRSVPStatusColor(context, rsvp),
        child: Icon(
          _getRSVPStatusIcon(rsvp),
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(_getRSVPStatusText(rsvp)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event: $eventAddress',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (rsvp.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rsvp.note,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showRSVPActions(context, rsvp, null),
      ),
      onTap: () => _viewRSVPDetails(context, rsvp, null),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        title: const Text('Error'),
        subtitle: Text(message),
      ),
    );
  }

  String _getRSVPStatusText(CalendarEventRSVP rsvp) {
    if (rsvp.isAccepted) return 'Accepted';
    if (rsvp.isDeclined) return 'Declined';
    if (rsvp.isTentative) return 'Tentative';
    return 'RSVP';
  }

  IconData _getRSVPStatusIcon(CalendarEventRSVP rsvp) {
    if (rsvp.isAccepted) return Icons.check_circle;
    if (rsvp.isDeclined) return Icons.cancel;
    if (rsvp.isTentative) return Icons.help_outline;
    return Icons.event_note;
  }

  Color _getRSVPStatusColor(BuildContext context, CalendarEventRSVP rsvp) {
    if (rsvp.isAccepted) return Colors.green.shade100;
    if (rsvp.isDeclined) return Colors.red.shade100;
    if (rsvp.isTentative) return Colors.orange.shade100;
    return Theme.of(context).colorScheme.secondaryContainer;
  }

  void _showRSVPActions(BuildContext context, CalendarEventRSVP rsvp, Model<dynamic>? parentEvent) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit RSVP'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to edit RSVP screen
            },
          ),
          if (parentEvent != null)
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('View Event'),
              onTap: () {
                Navigator.pop(context);
                _viewEventDetails(context, parentEvent);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete RSVP'),
            onTap: () {
              Navigator.pop(context);
              _deleteRSVP(context, rsvp);
            },
          ),
        ],
      ),
    );
  }

  void _viewRSVPDetails(BuildContext context, CalendarEventRSVP rsvp, Model<dynamic>? parentEvent) {
    // TODO: Navigate to RSVP details screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('RSVP details coming soon!')),
    );
  }

  void _deleteRSVP(BuildContext context, CalendarEventRSVP rsvp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete RSVP'),
        content: const Text('Are you sure you want to delete this RSVP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement RSVP deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('RSVP deletion coming soon!')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

