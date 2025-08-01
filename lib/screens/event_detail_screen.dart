import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common/profile_avatar.dart';

/// Event detail screen showing comprehensive information about a calendar event
class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  final Map<String, dynamic>? eventData;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.eventData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Debug logging
    debugPrint('EventDetail: eventData = $eventData');
    debugPrint('EventDetail: eventId = $eventId');
    
    // If we have event data passed in, use it. Otherwise query by ID.
    if (eventData != null && eventData!['event'] != null) {
      debugPrint('EventDetail: Using passed event data');
      final event = eventData!['event'];
      debugPrint('EventDetail: Building detail view with passed event');
      return _buildScaffoldWithEvent(context, ref, event);
    }

    // Query for the event by ID
    debugPrint('EventDetail: Querying for event ID: $eventId');
    final eventState = ref.watch(
      queryKinds(
        ids: {eventId},
        kinds: {31922, 31923, 31925, 31926, 31927}, // All calendar event kinds
        limit: 1,
        source: LocalAndRemoteSource(stream: false, background: false),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: switch (eventState) {
        StorageLoading() => () {
          debugPrint('EventDetail: StorageLoading state');
          return const Center(child: CircularProgressIndicator());
        }(),
        StorageError(:final exception) => () {
          debugPrint('EventDetail: StorageError - $exception');
          return Center(
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
                  'Failed to load event',
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
          );
        }(),
        StorageData(:final models) => () {
          debugPrint('EventDetail: StorageData - ${models.length} models found');
          if (models.isNotEmpty) {
            debugPrint('EventDetail: First model type: ${models.first.runtimeType}');
          }
          return models.isEmpty
              ? Center(
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
                        'Event not found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : _buildEventContent(context, ref, models.first);
        }(),
        _ => () {
          debugPrint('EventDetail: Unknown state');
          return const Center(child: Text('Loading...'));
        }(),
      },
    );
  }

  Widget _buildScaffoldWithEvent(BuildContext context, WidgetRef ref, dynamic event) {
    debugPrint('EventDetail: _buildScaffoldWithEvent called with event type: ${event.runtimeType}');
    final kind = event.event.kind;
    debugPrint('EventDetail: Event kind: $kind');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getEventTypeTitle(kind)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareEvent(context, event),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value, event),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy_id',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Event ID'),
                  ],
                ),
              ),
              if (kind == 31922 || kind == 31923)
                const PopupMenuItem(
                  value: 'rsvp',
                  child: Row(
                    children: [
                      Icon(Icons.event_available),
                      SizedBox(width: 8),
                      Text('RSVP'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildEventContent(context, ref, event),
    );
  }

  Widget _buildEventContent(BuildContext context, WidgetRef ref, dynamic event) {
    debugPrint('EventDetail: _buildEventContent called');
    final kind = event.event.kind;
    
    // Simple test content first
    final title = event.event.getFirstTagValue('title') ?? 'Untitled Event';
    final content = event.event.content;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple content to test
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Kind: $kind',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.isNotEmpty ? content : 'No description',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Original complex content (commented out for testing)
          // _buildEventHeader(context, ref, event),
          // const SizedBox(height: 24),
          // _buildEventDetails(context, ref, event),
          // if (kind == 31922 || kind == 31923) ...[
          //   const SizedBox(height: 24),
          //   _buildParticipants(context, ref, event),
          //   const SizedBox(height: 24),
          //   _buildRSVPs(context, ref, event),
          // ],
        ],
      ),
    );
  }

  Widget _buildEventHeader(BuildContext context, WidgetRef ref, dynamic event) {
    debugPrint('EventDetail: _buildEventHeader called');
    final title = event.event.getFirstTagValue('title') ?? 
                  event.event.getFirstTagValue('name') ?? 
                  'Untitled Event';
    debugPrint('EventDetail: Event title: $title');
    final kind = event.event.kind;
    
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event type badge
            Row(
              children: [
                Chip(
                  label: Text(_getEventTypeName(kind)),
                  backgroundColor: _getEventTypeColor(context, kind),
                ),
                const Spacer(),
                Text(
                  _formatEventDate(event),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            // Summary (if available)
            if (event.event.getFirstTagValue('summary') != null) ...[
              const SizedBox(height: 8),
              Text(
                event.event.getFirstTagValue('summary')!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Author info
            Row(
              children: [
                ProfileAvatar(profile: authorProfile, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created by',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      Text(
                        authorProfile?.name ?? 'Anonymous',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetails(BuildContext context, WidgetRef ref, dynamic event) {
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Timing information
            _buildTimingInfo(context, event),
            
            // Location
            if (event.event.getFirstTagValue('location') != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                Icons.location_on,
                'Location',
                event.event.getFirstTagValue('location')!,
                onTap: () => _openLocation(event.event.getFirstTagValue('location')!),
              ),
            ],
            
            // Image
            if (event.event.getFirstTagValue('image') != null) ...[
              const SizedBox(height: 16),
              _buildImageSection(context, event.event.getFirstTagValue('image')!),
            ],
            
            // Content/Description
            if (event.event.content.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildContentSection(context, ref, event.event.content),
            ],
            
            // Hashtags and References
            ..._buildHashtagsAndReferences(context, event),
            
            // Geohash
            if (event.event.getFirstTagValue('g') != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                Icons.map,
                'Area Code',
                event.event.getFirstTagValue('g')!,
              ),
            ],
            
            // Special fields for different event types
            if (event.event.kind == 31926) _buildAvailabilityDetails(context, event),
            if (event.event.kind == 31927) _buildAvailabilityBlockDetails(context, event),
            if (event.event.kind == 31925) _buildRSVPDetails(context, ref, event),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingInfo(BuildContext context, dynamic event) {
    final kind = event.event.kind;
    
    if (kind == 31922) {
      // Date-based event
      final startDate = event.event.getFirstTagValue('start');
      final endDate = event.event.getFirstTagValue('end');
      
      return Column(
        children: [
          _buildDetailRow(
            context,
            Icons.calendar_today,
            'Start Date',
            startDate ?? 'Not specified',
          ),
          if (endDate != null && endDate != startDate) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.calendar_today,
              'End Date',
              endDate,
            ),
          ],
        ],
      );
    } else if (kind == 31923) {
      // Time-based event
      final startTime = event.event.getFirstTagValue('start');
      final endTime = event.event.getFirstTagValue('end');
      final startTzid = event.event.getFirstTagValue('start_tzid');
      final endTzid = event.event.getFirstTagValue('end_tzid');
      
      return Column(
        children: [
          if (startTime != null)
            _buildDetailRow(
              context,
              Icons.schedule,
              'Start Time',
              _formatUnixTimestamp(startTime, startTzid),
            ),
          if (endTime != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.schedule,
              'End Time',
              _formatUnixTimestamp(endTime, endTzid ?? startTzid),
            ),
          ],
        ],
      );
    } else if (kind == 31927) {
      // Availability block
      final startTime = event.event.getFirstTagValue('start');
      final endTime = event.event.getFirstTagValue('end');
      
      return Column(
        children: [
          if (startTime != null)
            _buildDetailRow(
              context,
              Icons.block,
              'Block Start',
              _formatUnixTimestamp(startTime, null),
            ),
          if (endTime != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.block,
              'Block End',
              _formatUnixTimestamp(endTime, null),
            ),
          ],
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.open_in_new,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.image,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Event Image',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context, WidgetRef ref, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.description,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Description',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  List<Widget> _buildHashtagsAndReferences(BuildContext context, dynamic event) {
    final hashtags = event.event.getTags('t').map((tag) => tag.length > 1 ? tag[1] : '').where((tag) => tag.isNotEmpty).toList();
    final references = event.event.getTags('r').map((tag) => tag.length > 1 ? tag[1] : '').where((ref) => ref.isNotEmpty).toList();
    
    List<Widget> widgets = [];
    
    if (hashtags.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildHashtagsSection(context, hashtags),
      ]);
    }
    
    if (references.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildReferencesSection(context, references),
      ]);
    }
    
    return widgets;
  }

  Widget _buildHashtagsSection(BuildContext context, List<String> hashtags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tag,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Tags',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: hashtags.map((tag) => Chip(
            label: Text('#$tag'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildReferencesSection(BuildContext context, List<String> references) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.link,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'References',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...references.map((ref) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            onTap: () => _openUrl(ref),
            child: Text(
              ref,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildAvailabilityDetails(BuildContext context, dynamic event) {
    // TODO: Implement availability-specific details from our custom model
    return const SizedBox.shrink();
  }

  Widget _buildAvailabilityBlockDetails(BuildContext context, dynamic event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Availability Block',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This event blocks availability during the specified time range.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildRSVPDetails(BuildContext context, WidgetRef ref, dynamic event) {
    if (event is! CalendarEventRSVP) return const SizedBox.shrink();
    
    final rsvp = event;
    final status = rsvp.isAccepted ? 'Accepted' : 
                   rsvp.isDeclined ? 'Declined' : 
                   rsvp.isTentative ? 'Tentative' : 'Unknown';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'RSVP Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow(
          context,
          Icons.event_available,
          'Status',
          status,
        ),
        if (rsvp.eventAddress != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            Icons.event,
            'Event',
            rsvp.eventAddress!,
          ),
        ],
      ],
    );
  }

  Widget _buildParticipants(BuildContext context, WidgetRef ref, dynamic event) {
    final participantTags = event.event.getTags('p');
    if (participantTags.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participants',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...participantTags.map((tag) {
              final pubkey = tag.length > 1 ? tag[1] : '';
              final role = tag.length > 3 ? tag[3] : '';
              
              if (pubkey.isEmpty) return const SizedBox.shrink();
              
              // Get participant profile
              final profileState = ref.watch(
                query<Profile>(
                  authors: {pubkey},
                  limit: 1,
                  source: LocalAndRemoteSource(stream: false),
                ),
              );
              
              Profile? profile;
              if (profileState is StorageData<Profile>) {
                profile = profileState.models.isNotEmpty 
                    ? profileState.models.first 
                    : null;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ProfileAvatar(profile: profile, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Anonymous',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (role.isNotEmpty)
                            Text(
                              role,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRSVPs(BuildContext context, WidgetRef ref, dynamic event) {
    // Query for RSVPs to this event
    final eventAddress = '${event.event.kind}:${event.event.pubkey}:${event.event.getFirstTagValue('d') ?? ''}';
    
    final rsvpState = ref.watch(
      query<CalendarEventRSVP>(
        tags: {'#a': {eventAddress}},
        limit: 50,
        source: LocalAndRemoteSource(stream: true, background: true),
      ),
    );
    
    return switch (rsvpState) {
      StorageData(:final models) when models.isNotEmpty => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RSVPs (${models.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...models.map((rsvp) => _buildRSVPItem(context, ref, rsvp)),
            ],
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildRSVPItem(BuildContext context, WidgetRef ref, CalendarEventRSVP rsvp) {
    final status = rsvp.isAccepted ? 'Accepted' : 
                   rsvp.isDeclined ? 'Declined' : 
                   rsvp.isTentative ? 'Tentative' : 'RSVP';
    
    // Get RSVP author profile
    final profileState = ref.watch(
      query<Profile>(
        authors: {rsvp.event.pubkey},
        limit: 1,
        source: LocalAndRemoteSource(stream: false),
      ),
    );
    
    Profile? profile;
    if (profileState is StorageData<Profile>) {
      profile = profileState.models.isNotEmpty 
          ? profileState.models.first 
          : null;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ProfileAvatar(profile: profile, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? 'Anonymous',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getRSVPStatusColor(context, rsvp),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (rsvp.note.isNotEmpty)
                  Text(
                    rsvp.note,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getEventTypeTitle(int kind) {
    return switch (kind) {
      31922 => 'Date Event Details',
      31923 => 'Time Event Details',
      31925 => 'RSVP Details',
      31926 => 'Availability Details',
      31927 => 'Availability Block Details',
      _ => 'Event Details',
    };
  }

  String _getEventTypeName(int kind) {
    return switch (kind) {
      31922 => 'Date Event',
      31923 => 'Time Event',
      31925 => 'RSVP',
      31926 => 'Availability',
      31927 => 'Availability Block',
      _ => 'Event',
    };
  }

  Color _getEventTypeColor(BuildContext context, int kind) {
    return switch (kind) {
      31922 => Colors.blue.shade50,
      31923 => Colors.green.shade50,
      31925 => Colors.orange.shade50,
      31926 => Colors.purple.shade50,
      31927 => Colors.red.shade50,
      _ => Colors.grey.shade50,
    };
  }

  String _formatEventDate(dynamic event) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(event.event.createdAt * 1000);
    final now = DateTime.now();
    final difference = now.difference(createdAt).inDays;
    
    if (difference == 0) {
      return 'Created today';
    } else if (difference == 1) {
      return 'Created yesterday';
    } else if (difference < 7) {
      return 'Created $difference days ago';
    } else {
      return 'Created ${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  String _formatUnixTimestamp(String timestamp, String? timezone) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp) * 1000);
    final formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    final formattedTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    String result = '$formattedDate at $formattedTime';
    if (timezone != null && timezone.isNotEmpty) {
      result += ' ($timezone)';
    }
    return result;
  }

  Color _getRSVPStatusColor(BuildContext context, CalendarEventRSVP rsvp) {
    if (rsvp.isAccepted) return Colors.green;
    if (rsvp.isDeclined) return Colors.red;
    if (rsvp.isTentative) return Colors.orange;
    return Theme.of(context).colorScheme.outline;
  }

  // Action handlers
  void _shareEvent(BuildContext context, dynamic event) {
    final eventId = event.event.id;
    final title = event.event.getFirstTagValue('title') ?? 'Event';
    
    // Create a shareable text
    final shareText = 'Check out this event: $title\nEvent ID: $eventId';
    
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event details copied to clipboard')),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action, dynamic event) {
    switch (action) {
      case 'copy_id':
        Clipboard.setData(ClipboardData(text: event.event.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event ID copied to clipboard')),
        );
        break;
      case 'rsvp':
        // TODO: Navigate to RSVP screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RSVP functionality coming soon!')),
        );
        break;
    }
  }

  void _openLocation(String location) async {
    // Try to open as URL first, then as search query
    if (location.startsWith('http')) {
      _openUrl(location);
    } else {
      final encodedLocation = Uri.encodeComponent(location);
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedLocation';
      _openUrl(mapsUrl);
    }
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}