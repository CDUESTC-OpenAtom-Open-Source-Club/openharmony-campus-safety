import localUnitTest from './LocalUnit.test';
import eventSimulatorTest from './EventSimulator.test';

export default function testsuite() {
  localUnitTest();
  eventSimulatorTest();
}