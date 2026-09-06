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

export const DEMO_COURSES: Course[] = [
  {
    id: 'course_math',
    name: '高等数学',
    location: '教学楼A301',
    weekday: 1,
    startPeriod: 1,
    endPeriod: 2,
    startTime: '08:15',
    endTime: '09:50',
    color: CourseColor.BLUE
  },
  {
    id: 'course_english',
    name: '大学英语',
    location: '外语楼B203',
    weekday: 2,
    startPeriod: 1,
    endPeriod: 2,
    startTime: '08:15',
    endTime: '09:50',
    color: CourseColor.GREEN
  },
  {
    id: 'course_safety',
    name: '安全教育',
    location: '报告厅',
    weekday: 3,
    startPeriod: 3,
    endPeriod: 4,
    startTime: '10:05',
    endTime: '11:40',
    color: CourseColor.RED
  },
  {
    id: 'course_sport',
    name: '体育',
    location: '体育馆',
    weekday: 4,
    startPeriod: 7,
    endPeriod: 8,
    startTime: '16:40',
    endTime: '17:25',
    color: CourseColor.ORANGE
  },
  {
    id: 'course_structure',
    name: '数据结构',
    location: '实训楼C505',
    weekday: 7,
    startPeriod: 5,
    endPeriod: 6,
    startTime: '14:00',
    endTime: '15:35',
    color: CourseColor.PURPLE
  }
];
