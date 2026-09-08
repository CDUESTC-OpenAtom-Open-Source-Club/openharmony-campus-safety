import { User, UserRole } from '../main/ets/model/User';

export const TEST_ADMIN: User = {
  id: 'admin_test',
  name: '测试管理员',
  role: UserRole.ADMIN
};

export const TEST_STUDENT: User = {
  id: 'student_test',
  name: '测试学生',
  role: UserRole.STUDENT
};
