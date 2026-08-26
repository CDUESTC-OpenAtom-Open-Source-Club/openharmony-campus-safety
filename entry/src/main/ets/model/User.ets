export enum UserRole {
  STUDENT = '学生',
  TEACHER = '教师',
  SECURITY = '安保人员',
  ADMIN = '管理员'
}

export interface User {
  id: string;
  name: string;
  role: UserRole;
  department?: string;
}