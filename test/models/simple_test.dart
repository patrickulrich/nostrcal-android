import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostrcal/models/models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer();
    final config = StorageConfiguration(keepSignatures: false);
    await container.read(initializationProvider(config).future);
    
    // Register custom models
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

  tearDown(() {
    container.dispose();
  });

  group('Calendar Models Basic Test', () {
    test('CalendarAvailability can be created', () {
      final availability = PartialCalendarAvailability(
        calendarAddress: '31924:alice-pubkey:cal-work',
        title: 'Office Hours',
        scheduleBlocks: [
          ['MO', '09:00', '17:00'],
          ['TU', '09:00', '17:00'],
        ],
        description: 'Weekly office hours',
      ).dummySign();

      expect(availability.title, 'Office Hours');
      // Test that it contains the calendar reference
      expect(availability.event.getFirstTagValue('a'), '31924:alice-pubkey:cal-work');
      expect(availability.scheduleBlocks.length, 2);
      expect(availability.description, 'Weekly office hours');
    });

    test('CalendarAvailabilityBlock can be created', () {
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(hours: 2));

      final block = PartialCalendarAvailabilityBlock(
        startTime: startTime,
        endTime: endTime,
        description: 'Busy with meeting',
      ).dummySign();

      // Due to precision loss in toSeconds conversion, check within 1 second
      expect(block.startTime!.difference(startTime).inSeconds.abs(), lessThan(2));
      expect(block.endTime!.difference(endTime).inSeconds.abs(), lessThan(2));
      expect(block.description, 'Busy with meeting');
      expect(block.hasValidTimeRange, true);
    });
  });
}