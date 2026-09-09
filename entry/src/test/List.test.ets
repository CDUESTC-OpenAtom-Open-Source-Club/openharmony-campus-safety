import localUnitTest from './LocalUnit.test';
import eventSimulatorTest from './EventSimulator.test';
import eventRepositoryTest from './EventRepository.test';
import eventWorkflowTest from './EventWorkflow.test';
import stabilityTest from './Stability.test';
import permissionTest from './Permission.test';
import emergencyContactTest from './EmergencyContact.test';

export default function testsuite() {
  localUnitTest();
  eventSimulatorTest();
  eventRepositoryTest();
  eventWorkflowTest();
  stabilityTest();
  permissionTest();
  emergencyContactTest();
}
