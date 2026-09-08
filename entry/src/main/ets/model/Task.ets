export enum TaskStatus {
  PENDING = '待处理',
  PROCESSING = '处理中',
  REVIEW = '待审核',
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

  // 巡检人员填写的处理结果
  result?: string;

  // 提交管理员审核的时间
  submittedTime?: string;

  // 最近一次审核驳回原因；重新提交审核时清除
  rejectionReason?: string;

  // 管理员审核通过后的完成时间
  completedTime?: string;
}
