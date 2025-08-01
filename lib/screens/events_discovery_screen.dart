import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/profile_avatar.dart';

/// Events discovery screen for finding public calendar events
class EventsDiscoveryScreen extends HookConsumerWidget {
  const EventsDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(Signer.activePubkeyProvider);
    final searchController = useTextEditingController();
    final selectedFilter = useState<EventFilter>(EventFilter.all);
    final searchQuery = useState<String>('');
    final currentLimit = useState<int>(100); // Start with 100 events

    // Redirect to auth if not signed in
    if (pubkey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Events'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(context, searchController, selectedFilter, searchQuery),
          Expanded(
            child: _buildEventsList(context, ref, searchQuery.value, selectedFilter.value, currentLimit),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(
    BuildContext context,
    TextEditingController searchController,
    ValueNotifier<EventFilter> selectedFilter,
    ValueNotifier<String> searchQuery,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search events',
              hintText: 'Search by title, location, or tags...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        searchQuery.value = '';
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              searchQuery.value = value;
            },
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: EventFilter.values.map((filter) {
                final isSelected = selectedFilter.value == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      selectedFilter.value = filter;
                    },
                    avatar: Icon(
                      filter.icon,
                      size: 18,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    WidgetRef ref,
    String searchQuery,
    EventFilter filter,
    ValueNotifier<int> currentLimit,
  ) {
    // Query all public calendar events from local storage and relays
    final eventsState = ref.watch(
      queryKinds(
        kinds: {31922, 31923}, // Date-based and time-based calendar events
        limit: currentLimit.value,
        source: LocalAndRemoteSource(stream: true, background: true),
      ),
    );

    return switch (eventsState) {
      StorageLoading() => const Center(child: CircularProgressIndicator()),
      StorageError(:final exception) => Center(
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
              exception.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      StorageData(:final models) => () {
        // Filter and search events
        final filteredEvents = _filterEvents(models, searchQuery, filter);
        
        if (filteredEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isNotEmpty || filter != EventFilter.all
                      ? 'No events match your search'
                      : 'No events found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  searchQuery.isNotEmpty || filter != EventFilter.all
                      ? 'Try adjusting your search or filters'
                      : 'Check back later for new events',
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
          itemCount: filteredEvents.length + 1, // +1 for load more button
          itemBuilder: (context, index) {
            if (index == filteredEvents.length) {
              // Load more button at the end
              return _buildLoadMoreButton(context, currentLimit, filteredEvents.length, models.length);
            }
            final event = filteredEvents[index];
            return _buildEventCard(context, ref, event);
          },
        );
      }(),
      _ => const Center(child: Text('Loading events...')),
    };
  }

  List<dynamic> _filterEvents(List<dynamic> events, String searchQuery, EventFilter filter) {
    var filtered = events.where((event) {
      // Apply filter
      switch (filter) {
        case EventFilter.all:
          break;
        case EventFilter.today:
          if (!_isEventToday(event)) return false;
          break;
        case EventFilter.thisWeek:
          if (!_isEventThisWeek(event)) return false;
          break;
        case EventFilter.thisMonth:
          if (!_isEventThisMonth(event)) return false;
          break;
        case EventFilter.dateEvents:
          if (event.event.kind != 31922) return false;
          break;
        case EventFilter.timeEvents:
          if (event.event.kind != 31923) return false;
          break;
      }

      // Apply search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final title = event.event.getFirstTagValue('title')?.toLowerCase() ?? '';
        final content = event.event.content.toLowerCase();
        final location = event.event.getFirstTagValue('location')?.toLowerCase() ?? '';
        final tags = event.tags.map((tag) => tag.toLowerCase()).join(' ');

        if (!title.contains(query) && 
            !content.contains(query) && 
            !location.contains(query) && 
            !tags.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by start time (most recent first)
    filtered.sort((a, b) {
      final aTime = _getEventStartTime(a);
      final bTime = _getEventStartTime(b);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  bool _isEventToday(dynamic event) {
    final startTime = _getEventStartTime(event);
    if (startTime == null) return false;
    final now = DateTime.now();
    return startTime.year == now.year && 
           startTime.month == now.month && 
           startTime.day == now.day;
  }

  bool _isEventThisWeek(dynamic event) {
    final startTime = _getEventStartTime(event);
    if (startTime == null) return false;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return startTime.isAfter(weekStart) && startTime.isBefore(weekEnd);
  }

  bool _isEventThisMonth(dynamic event) {
    final startTime = _getEventStartTime(event);
    if (startTime == null) return false;
    final now = DateTime.now();
    return startTime.year == now.year && startTime.month == now.month;
  }

  DateTime? _getEventStartTime(dynamic event) {
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
    return null;
  }

  Widget _buildEventCard(BuildContext context, WidgetRef ref, dynamic event) {
    final title = event.event.getFirstTagValue('title') ?? 'Untitled Event';
    final description = event.event.content;
    final location = event.event.getFirstTagValue('location');
    final startTime = _getEventStartTime(event);
    
    // Get author profile
    final authorPubkey = event.event.pubkey;
    final authorProfileState = ref.watch(
      query<Profile>(
        authors: {authorPubkey},
        limit: 1,
        source: LocalAndRemoteSource(stream: false),
      ),
    );

    Profile? authorProfile;
    if (authorProfileState is StorageData<Profile>) {
      authorProfile = authorProfileState.models.isNotEmpty 
          ? authorProfileState.models.first 
          : null;
    }

    String timeInfo = '';
    if (event.event.kind == 31922) {
      // Date-based event
      final startDate = event.event.getFirstTagValue('start');
      final endDate = event.event.getFirstTagValue('end');
      timeInfo = endDate != null ? '$startDate to $endDate' : startDate ?? '';
    } else if (event.event.kind == 31923 && startTime != null) {
      // Time-based event
      timeInfo = _formatDateTime(startTime);
      final endTime = event.event.getFirstTagValue('end');
      if (endTime != null) {
        final end = DateTime.fromMillisecondsSinceEpoch(int.parse(endTime) * 1000);
        timeInfo += ' - ${_formatTime(end)}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _viewEventDetails(context, event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event header with author
              Row(
                children: [
                  ProfileAvatar(
                    profile: authorProfile,
                    radius: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorProfile?.name ?? 'Anonymous',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      event.event.kind == 31922 ? 'Date Event' : 'Time Event',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    backgroundColor: event.event.kind == 31922 
                        ? Colors.blue.shade50 
                        : Colors.green.shade50,
                  ),
                ],
              ),
              if (timeInfo.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeInfo,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: event.tags.take(3).map<Widget>((tag) {
                    return Chip(
                      label: Text(
                        '#$tag',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(
    BuildContext context, 
    ValueNotifier<int> currentLimit, 
    int filteredCount, 
    int totalCount
  ) {
    // Calculate next limit using exponential progression: 100 -> 200 -> 400 -> 800 -> 1600
    int getNextLimit(int current) {
      if (current == 100) return 200;
      if (current < 1600) return current * 2;
      return current + 1600; // Keep adding 1600 after reaching the max
    }
    
    final nextLimit = getNextLimit(currentLimit.value);
    final hasMoreData = totalCount >= currentLimit.value;
    
    if (!hasMoreData) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'All events loaded ($totalCount total)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: FilledButton.icon(
          onPressed: () {
            currentLimit.value = nextLimit;
          },
          icon: const Icon(Icons.expand_more),
          label: Text('Load More (${currentLimit.value} → $nextLimit)'),
        ),
      ),
    );
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference == 1) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    } else if (difference == -1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else if (difference > 1 && difference <= 7) {
      final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dateTime.weekday - 1];
      return '$weekday at ${_formatTime(dateTime)}';
    } else {
      final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dateTime.month - 1];
      return '$month ${dateTime.day} at ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

/// Event filter options
enum EventFilter {
  all('All Events', Icons.event),
  today('Today', Icons.today),
  thisWeek('This Week', Icons.date_range),
  thisMonth('This Month', Icons.calendar_month),
  dateEvents('Date Events', Icons.calendar_view_day),
  timeEvents('Time Events', Icons.schedule);

  const EventFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}