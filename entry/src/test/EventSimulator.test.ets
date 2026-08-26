import { describe, it, expect } from '@ohos/hypium';

import {
  SecurityEvent,
  EventStatus,
  EventType,
  EventPriority
} from '../main/ets/model/SecurityEvent';

import { EventSimulator } from '../main/ets/simulator/EventSimulator';

export default function eventSimulatorTest() {
  describe('EventSimulatorTest', () => {
    it('generate_event_fields_complete', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(0);
      expect(event.id.length > 0).assertTrue();
      expect(event.title.length > 0).assertTrue();
      expect(event.location.length > 0).assertTrue();
      expect(event.description.length > 0).assertTrue();
      expect(event.reporter.length > 0).assertTrue();
      expect(event.reportTime.length > 0).assertTrue();
      expect(event.type !== undefined).assertTrue();
      expect(event.priority !== undefined).assertTrue();
    });

    it('generate_event_default_status_pending', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(0);
      expect(event.status).assertEqual(EventStatus.PENDING);
    });

    it('generate_event_by_template_index_maps_type', 0, () => {
      const fireEvent: SecurityEvent = EventSimulator.simulateEvent(0);
      expect(fireEvent.type).assertEqual(EventType.FIRE);

      const electricEvent: SecurityEvent = EventSimulator.simulateEvent(1);
      expect(electricEvent.type).assertEqual(EventType.ELECTRIC);

      const facilityEvent: SecurityEvent = EventSimulator.simulateEvent(2);
      expect(facilityEvent.type).assertEqual(EventType.FACILITY);
    });

    it('generate_random_event_has_valid_type', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent();
      const validTypes: EventType[] = [EventType.FIRE, EventType.ELECTRIC, EventType.FACILITY];
      expect(validTypes).assertContain(event.type);
    });

    it('generate_batch_returns_expected_count', 0, () => {
      const events: SecurityEvent[] = EventSimulator.simulateBatch(10);
      expect(events.length).assertEqual(10);
    });

    it('generate_batch_ids_are_unique', 0, () => {
      const events: SecurityEvent[] = EventSimulator.simulateBatch(50);
      const idSet: Set<string> = new Set<string>();
      events.forEach((event: SecurityEvent) => {
        idSet.add(event.id);
      });
      expect(idSet.size).assertEqual(50);
    });

    it('batch_with_non_positive_count_returns_empty', 0, () => {
      expect(EventSimulator.simulateBatch(-1).length).assertEqual(0);
      expect(EventSimulator.simulateBatch(0).length).assertEqual(0);
    });

    it('event_with_invalid_template_index_falls_back_safely', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(99);
      expect(event.id.length > 0).assertTrue();
      expect(event.title.length > 0).assertTrue();
      expect(event.status).assertEqual(EventStatus.PENDING);
    });

    it('event_with_non_integer_index_falls_back_safely', 0, () => {
      const event: SecurityEvent = EventSimulator.simulateEvent(1.5);
      expect(event.id.length > 0).assertTrue();
      expect(event.title.length > 0).assertTrue();
      expect(event.type !== undefined).assertTrue();
    });
  });
}
