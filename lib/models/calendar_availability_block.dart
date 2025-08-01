import 'package:models/models.dart';

/// A user's specific busy time block for privacy-preserving scheduling.
///
/// Calendar Availability Block events publish specific time ranges when a user 
/// is busy without exposing event details or social connections. This enables 
/// booking systems to determine availability while preserving privacy.
class CalendarAvailabilityBlock extends ParameterizableReplaceableModel<CalendarAvailabilityBlock> {
  CalendarAvailabilityBlock.fromMap(super.map, super.ref) : super.fromMap();

  /// Inclusive start timestamp in seconds since Unix epoch
  DateTime? get startTime {
    final value = event.getFirstTagValue('start');
    return value != null ? int.tryParse(value)?.toDate() : null;
  }

  /// Exclusive end timestamp in seconds since Unix epoch
  DateTime? get endTime {
    final value = event.getFirstTagValue('end');
    return value != null ? int.tryParse(value)?.toDate() : null;
  }

  /// Duration of this busy block
  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }

  /// Whether this block is currently active (ongoing)
  bool get isActive {
    final now = DateTime.now();
    return startTime != null && 
           endTime != null && 
           now.isAfter(startTime!) && 
           now.isBefore(endTime!);
  }

  /// Whether this block is in the past
  bool get isPast {
    final now = DateTime.now();
    return endTime != null && now.isAfter(endTime!);
  }

  /// Whether this block is in the future
  bool get isFuture {
    final now = DateTime.now();
    return startTime != null && now.isBefore(startTime!);
  }

  /// Whether this block has valid time range
  bool get hasValidTimeRange {
    return startTime != null && 
           endTime != null && 
           endTime!.isAfter(startTime!);
  }

  /// Optional description of the busy block
  String get description => event.content;

  /// Whether this block has a description
  bool get hasDescription => description.isNotEmpty;
}

/// Mutable version of CalendarAvailabilityBlock for creation and editing.
class PartialCalendarAvailabilityBlock extends ParameterizableReplaceablePartialModel<CalendarAvailabilityBlock> {
  PartialCalendarAvailabilityBlock({
    required DateTime startTime,
    required DateTime endTime,
    String description = '',
    String? identifier,
    DateTime? createdAt,
  }) : super.fromMap({
          'kind': 31927,
          'content': description,
          'created_at': (createdAt ?? DateTime.now()).toSeconds(),
          'tags': <List<String>>[],
        }) {
    this.identifier = identifier ?? Utils.generateRandomHex64().substring(0, 16);
    this.startTime = startTime;
    this.endTime = endTime;
  }

  /// Create a busy block from an existing calendar event
  PartialCalendarAvailabilityBlock.fromEvent({
    required DateTime startTime,
    required DateTime endTime,
    String? identifier,
    DateTime? createdAt,
  }) : this(
          startTime: startTime,
          endTime: endTime,
          description: '',
          identifier: identifier,
          createdAt: createdAt,
        );

  PartialCalendarAvailabilityBlock.fromMap(super.map) : super.fromMap();

  /// Inclusive start timestamp in seconds since Unix epoch
  DateTime? get startTime {
    final value = event.getFirstTagValue('start');
    return value != null ? int.tryParse(value)?.toDate() : null;
  }

  set startTime(DateTime? value) => 
      event.setTagValue('start', value?.toSeconds().toString());

  /// Exclusive end timestamp in seconds since Unix epoch
  DateTime? get endTime {
    final value = event.getFirstTagValue('end');
    return value != null ? int.tryParse(value)?.toDate() : null;
  }

  set endTime(DateTime? value) => 
      event.setTagValue('end', value?.toSeconds().toString());

  /// Optional description of the busy block
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';

  /// Sets both start and end times in one operation
  void setTimeRange(DateTime start, DateTime end) {
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      throw ArgumentError('End time must be after start time');
    }
    startTime = start;
    endTime = end;
  }

  /// Extends the end time of this block
  void extendEndTime(DateTime newEndTime) {
    if (startTime != null && newEndTime.isBefore(startTime!)) {
      throw ArgumentError('New end time must be after start time');
    }
    endTime = newEndTime;
  }

  /// Moves the entire block by a duration
  void moveBlock(Duration offset) {
    if (startTime != null && endTime != null) {
      startTime = startTime!.add(offset);
      endTime = endTime!.add(offset);
    }
  }

  /// Creates a block for a specific duration from start time
  void setDuration(DateTime start, Duration duration) {
    startTime = start;
    endTime = start.add(duration);
  }
}