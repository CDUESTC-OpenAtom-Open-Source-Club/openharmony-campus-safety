import localUnitTest from './LocalUnit.test';
import eventSimulatorTest from './EventSimulator.test';
import eventRepositoryTest from './EventRepository.test';
import eventWorkflowTest from './EventWorkflow.test';

export default function testsuite() {
  localUnitTest();
  eventSimulatorTest();
  eventRepositoryTest();
  eventWorkflowTest();
}