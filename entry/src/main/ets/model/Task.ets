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
  // 本地安保账号 ID，不使用显示名称代替责任人标识
  assignee: string;
  // 管理员实际下发任务的时间
  createTime: string;
  // 负责人首次接单时间
  acceptedTime?: string;
  // 根据事件优先级生成的处理期限
  deadline?: string;
  status: TaskStatus;

  // 巡检人员填写的处理结果
  result?: string;

  // 提交管理员审核的时间
  submittedTime?: string;

  // 最近一次审核驳回原因；重新提交审核时清除
  rejectionReason?: string;

  // 管理员审核通过后的完成时间
  completedTime?: string;

  // 现场处置前、处置后的图片证据（应用私有目录路径）
  beforeAttachmentPaths?: string[];
  afterAttachmentPaths?: string[];
}
