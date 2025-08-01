import 'package:models/models.dart';

/// A user's recurring availability schedule for booking appointments.
///
/// Calendar Availability events advertise a user's recurring open hours and 
/// booking parameters. They're typically linked to a Calendar and help clients
/// compute real-time free slots by combining the template with other calendar events.
class CalendarAvailability extends ParameterizableReplaceableModel<CalendarAvailability> {
  CalendarAvailability.fromMap(super.map, super.ref) : super.fromMap();

  /// Links this availability template to a calendar
  BelongsTo<Calendar>? get calendar {
    final addresses = event.getTagSetValues('a');
    if (addresses.isEmpty) return null;
    
    final calendarAddress = addresses.firstOrNull;
    if (calendarAddress == null) return null;
    
    return BelongsTo<Calendar>(
      ref,
      Request.fromIds([calendarAddress]),
    );
  }

  /// Label shown to bookers
  String? get title => event.getFirstTagValue('title');

  /// Weekly recurring time blocks when user is available
  /// 
  /// Format: [day, startTime, endTime] where day is ISO-8601 day code
  /// (MO, TU, WE, TH, FR, SA, SU) and times are 24-hour format (HH:MM)
  List<List<String>> get scheduleBlocks {
    return event.tags
        .where((tag) => tag.isNotEmpty && tag[0] == 'sch' && tag.length >= 4)
        .map((tag) => [tag[1], tag[2], tag[3]])
        .toList();
  }

  /// IANA time zone for all schedule blocks
  String? get timeZone => event.getFirstTagValue('tzid');

  /// Duration for each booking slot in ISO-8601 format
  String? get duration => event.getFirstTagValue('duration');

  /// Gap between starts of consecutive booking slots in ISO-8601 format
  String? get interval => event.getFirstTagValue('interval');

  /// Time to reserve before each booking slot in ISO-8601 format
  String? get bufferBefore => event.getFirstTagValue('buffer_before');

  /// Time to reserve after each booking slot in ISO-8601 format
  String? get bufferAfter => event.getFirstTagValue('buffer_after');

  /// Minimum advance notice required for bookings in ISO-8601 format
  String? get minNotice => event.getFirstTagValue('min_notice');

  /// Maximum advance period for bookings in ISO-8601 format
  String? get maxAdvance => event.getFirstTagValue('max_advance');

  /// Whether max advance period counts business days only
  bool get maxAdvanceBusiness {
    final value = event.getFirstTagValue('max_advance_business');
    return value == 'true';
  }

  /// Payment amount required to confirm a booking in satoshis
  int? get amount {
    final value = event.getFirstTagValue('amount');
    return value != null ? int.tryParse(value) : null;
  }

  /// Whether this availability template requires payment
  bool get requiresPayment => amount != null && amount! > 0;

  /// The availability description
  String get description => event.content;

  /// Whether this template has any schedule blocks defined
  bool get hasSchedule => scheduleBlocks.isNotEmpty;

  /// Number of schedule blocks in this template
  int get scheduleBlockCount => scheduleBlocks.length;
}

/// Mutable version of CalendarAvailability for creation and editing.
class PartialCalendarAvailability extends ParameterizableReplaceablePartialModel<CalendarAvailability> {
  PartialCalendarAvailability({
    required String calendarAddress,
    required String title,
    required List<List<String>> scheduleBlocks,
    String? timeZone,
    String duration = 'PT30M',
    String? interval,
    String? bufferBefore,
    String? bufferAfter,
    String? minNotice,
    String? maxAdvance,
    bool maxAdvanceBusiness = false,
    int? amount,
    String description = '',
    String? identifier,
    DateTime? createdAt,
  }) : super.fromMap({
          'kind': 31926,
          'content': description,
          'created_at': (createdAt ?? DateTime.now()).toSeconds(),
          'tags': <List<String>>[],
        }) {
    this.identifier = identifier ?? Utils.generateRandomHex64().substring(0, 16);
    this.calendarAddress = calendarAddress;
    this.title = title;
    this.scheduleBlocks = scheduleBlocks;
    if (timeZone != null) this.timeZone = timeZone;
    this.duration = duration;
    if (interval != null) this.interval = interval;
    if (bufferBefore != null) this.bufferBefore = bufferBefore;
    if (bufferAfter != null) this.bufferAfter = bufferAfter;
    if (minNotice != null) this.minNotice = minNotice;
    if (maxAdvance != null) this.maxAdvance = maxAdvance;
    this.maxAdvanceBusiness = maxAdvanceBusiness;
    if (amount != null) this.amount = amount;
  }

  PartialCalendarAvailability.fromMap(super.map) : super.fromMap();

  /// Links this availability template to a calendar
  String? get calendarAddress => event.getFirstTagValue('a');
  set calendarAddress(String? value) => event.setTagValue('a', value);

  /// Label shown to bookers
  String? get title => event.getFirstTagValue('title');
  set title(String? value) => event.setTagValue('title', value);

  /// Weekly recurring time blocks when user is available
  List<List<String>> get scheduleBlocks {
    return event.tags
        .where((tag) => tag.isNotEmpty && tag[0] == 'sch' && tag.length >= 4)
        .map((tag) => [tag[1], tag[2], tag[3]])
        .toList();
  }

  set scheduleBlocks(List<List<String>> blocks) {
    // Remove existing schedule blocks
    event.tags.removeWhere((tag) => tag.isNotEmpty && tag[0] == 'sch');
    
    // Add new schedule blocks
    for (final block in blocks) {
      if (block.length >= 3) {
        event.tags.add(['sch', block[0], block[1], block[2]]);
      }
    }
  }

  /// Adds a schedule block
  void addScheduleBlock(String day, String startTime, String endTime) {
    event.tags.add(['sch', day, startTime, endTime]);
  }

  /// Removes a schedule block
  void removeScheduleBlock(String day, String startTime, String endTime) {
    event.tags.removeWhere((tag) => 
        tag.length >= 4 && 
        tag[0] == 'sch' && 
        tag[1] == day && 
        tag[2] == startTime && 
        tag[3] == endTime);
  }

  /// IANA time zone for all schedule blocks
  String? get timeZone => event.getFirstTagValue('tzid');
  set timeZone(String? value) => event.setTagValue('tzid', value);

  /// Duration for each booking slot in ISO-8601 format
  String? get duration => event.getFirstTagValue('duration');
  set duration(String? value) => event.setTagValue('duration', value);

  /// Gap between starts of consecutive booking slots in ISO-8601 format
  String? get interval => event.getFirstTagValue('interval');
  set interval(String? value) => event.setTagValue('interval', value);

  /// Time to reserve before each booking slot in ISO-8601 format
  String? get bufferBefore => event.getFirstTagValue('buffer_before');
  set bufferBefore(String? value) => event.setTagValue('buffer_before', value);

  /// Time to reserve after each booking slot in ISO-8601 format
  String? get bufferAfter => event.getFirstTagValue('buffer_after');
  set bufferAfter(String? value) => event.setTagValue('buffer_after', value);

  /// Minimum advance notice required for bookings in ISO-8601 format
  String? get minNotice => event.getFirstTagValue('min_notice');
  set minNotice(String? value) => event.setTagValue('min_notice', value);

  /// Maximum advance period for bookings in ISO-8601 format
  String? get maxAdvance => event.getFirstTagValue('max_advance');
  set maxAdvance(String? value) => event.setTagValue('max_advance', value);

  /// Whether max advance period counts business days only
  bool get maxAdvanceBusiness {
    final value = event.getFirstTagValue('max_advance_business');
    return value == 'true';
  }

  set maxAdvanceBusiness(bool value) => 
      event.setTagValue('max_advance_business', value ? 'true' : 'false');

  /// Payment amount required to confirm a booking in satoshis
  int? get amount {
    final value = event.getFirstTagValue('amount');
    return value != null ? int.tryParse(value) : null;
  }

  set amount(int? value) => event.setTagValue('amount', value?.toString());

  /// The availability description
  String? get description => event.content.isEmpty ? null : event.content;
  set description(String? value) => event.content = value ?? '';
}