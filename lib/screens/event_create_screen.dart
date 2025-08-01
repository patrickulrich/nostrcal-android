import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:async_button_builder/async_button_builder.dart';

/// Screen for creating new calendar events
class EventCreateScreen extends HookConsumerWidget {
  const EventCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedDate = useState<DateTime>(DateTime.now());
    final startTime = useState<TimeOfDay>(TimeOfDay.now());
    final endTime = useState<TimeOfDay>(
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)))
    );
    final isAllDay = useState<bool>(false);
    final locationController = useTextEditingController();

    final pubkey = ref.watch(Signer.activePubkeyProvider);
    final signer = ref.watch(Signer.activeSignerProvider);

    if (pubkey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Event'),
        actions: [
          AsyncButtonBuilder(
            child: const Text('Save'),
            onPressed: () => _saveEvent(
              context,
              ref,
              signer!,
              titleController.text,
              descriptionController.text,
              selectedDate.value,
              startTime.value,
              endTime.value,
              isAllDay.value,
              locationController.text,
            ),
            builder: (context, child, callback, buttonState) {
              return TextButton(
                onPressed: buttonState.maybeWhen(
                  loading: () => null,
                  orElse: () => callback,
                ),
                child: buttonState.maybeWhen(
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  orElse: () => child,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                hintText: 'Enter event title',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Description field
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter event description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Date picker
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(_formatDate(selectedDate.value)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate.value,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date != null) {
                    selectedDate.value = date;
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // All-day toggle
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.schedule),
                title: const Text('All Day'),
                subtitle: const Text('Event lasts the entire day'),
                value: isAllDay.value,
                onChanged: (value) {
                  isAllDay.value = value;
                },
              ),
            ),
            const SizedBox(height: 8),

            // Time pickers (only if not all day)
            if (!isAllDay.value) ...[
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Start Time'),
                        subtitle: Text(startTime.value.format(context)),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: startTime.value,
                          );
                          if (time != null) {
                            startTime.value = time;
                            
                            // Auto-update end time to be 1 hour later
                            final startDateTime = DateTime(
                              selectedDate.value.year,
                              selectedDate.value.month,
                              selectedDate.value.day,
                              time.hour,
                              time.minute,
                            );
                            final endDateTime = startDateTime.add(const Duration(hours: 1));
                            endTime.value = TimeOfDay.fromDateTime(endDateTime);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled),
                        title: const Text('End Time'),
                        subtitle: Text(endTime.value.format(context)),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: endTime.value,
                          );
                          if (time != null) {
                            endTime.value = time;
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Location field
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Enter location (optional)',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),

            // Help text
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Event Privacy',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This event will be published to Nostr and visible to others. '
                      'For private events, consider using encrypted calendar features.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEvent(
    BuildContext context,
    WidgetRef ref,
    Signer signer,
    String title,
    String description,
    DateTime selectedDate,
    TimeOfDay startTime,
    TimeOfDay endTime,
    bool isAllDay,
    String location,
  ) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }

    try {
      if (isAllDay) {
        // Create date-based calendar event
        final event = PartialDateBasedCalendarEvent(
          title: title.trim(),
          startDate: '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
          description: description.trim().isEmpty ? null : description.trim(),
          location: location.trim().isEmpty ? null : location.trim(),
        );
        
        final signedEvent = await event.signWith(signer);
        await ref.read(storageNotifierProvider.notifier).save({signedEvent});
        await ref.read(storageNotifierProvider.notifier).publish({signedEvent});
      } else {
        // Create time-based calendar event
        final startDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          startTime.hour,
          startTime.minute,
        );
        
        final endDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          endTime.hour,
          endTime.minute,
        );

        // Validate times
        if (endDateTime.isBefore(startDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time')),
          );
          return;
        }

        final event = PartialTimeBasedCalendarEvent(
          title: title.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          description: description.trim().isEmpty ? null : description.trim(),
          location: location.trim().isEmpty ? null : location.trim(),
        );
        
        final signedEvent = await event.signWith(signer);
        await ref.read(storageNotifierProvider.notifier).save({signedEvent});
        await ref.read(storageNotifierProvider.notifier).publish({signedEvent});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create event: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
}