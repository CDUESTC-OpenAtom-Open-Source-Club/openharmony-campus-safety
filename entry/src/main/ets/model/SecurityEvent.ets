export enum EventStatus {
  PENDING = '待确认',
  CONFIRMED = '已确认',
  PROCESSING = '处理中',
  REVIEW = '待审核',
  COMPLETED = '已完成'
}

export enum EventPriority {
  LOW = '低',
  MEDIUM = '中',
  HIGH = '高',
  URGENT = '紧急'
}

export enum EventType {
  FIRE = '消防安全',
  ELECTRIC = '用电安全',
  FACILITY = '设施安全',
  CAMPUS = '校园秩序',
  OTHER = '其他'
}

export interface SecurityEvent {
  id: string;
  title: string;
  type: EventType;
  location: string;
  description: string;
  reporter: string;
  reportTime: string;
  status: EventStatus;
  priority: EventPriority;
  handler?: string;
}