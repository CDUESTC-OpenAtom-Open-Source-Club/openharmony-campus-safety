export enum CourseColor {
  BLUE = 'BLUE',
  GREEN = 'GREEN',
  RED = 'RED',
  ORANGE = 'ORANGE',
  PURPLE = 'PURPLE'
}

export interface Course {
  id: string;
  name: string;
  location: string;
  weekday: number;
  startPeriod: number;
  endPeriod: number;
  startTime: string;
  endTime: string;
  color: CourseColor;
}
