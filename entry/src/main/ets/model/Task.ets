export enum TaskStatus {
  PENDING = '待处理',
  PROCESSING = '处理中',
  COMPLETED = '已完成'
}

export interface Task {
  id: string;
  eventId: string;
  title: string;
  location: string;
  description: string;
  assignee: string;
  createTime: string;
  status: TaskStatus;
}