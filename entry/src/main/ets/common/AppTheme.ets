/**
 * 鸿蒙智安统一视觉设计令牌 (Design Tokens)。
 *
 * 采用专业级智慧安防数字化指挥中心风格：
 * 极简冷灰底白画布、深邃安防蓝主色、高冷岩板蓝灰、清爽冷青辅色，
 * 搭配精确的警示冷橙与应急冷红，呈现高质感、现代化的工控与安全协同质感。
 */
export class AppTheme {
  // 画布与容器表面
  static readonly canvas: string = '#F8FAFC';
  static readonly surface: string = '#FFFFFF';
  static readonly surfaceMuted: string = '#F1F5F9';
  static readonly surfaceSubtle: string = '#EDF2F7';

  // 文字与排版层次
  static readonly ink: string = '#0F172A';
  static readonly inkSoft: string = '#334155';
  static readonly muted: string = '#64748B';
  static readonly line: string = '#E2E8F0';
  static readonly lineStrong: string = '#CBD5E1';

  // 核心安防主色（科技蓝系列）
  static readonly accent: string = '#2563EB';
  static readonly accentDark: string = '#0B192C';
  static readonly accentDeep: string = '#1E3A8A';
  static readonly accentSoft: string = '#EFF6FF';

  // 辅助状态色
  static readonly cyan: string = '#0284C7';
  static readonly cyanSoft: string = '#E0F2FE';
  static readonly amber: string = '#D97706';
  static readonly amberSoft: string = '#FEF3C7';
  static readonly danger: string = '#DC2626';
  static readonly dangerSoft: string = '#FEF2F2';
  static readonly success: string = '#059669';
  static readonly successSoft: string = '#ECFDF5';
  static readonly info: string = '#0284C7';
  static readonly infoSoft: string = '#F0F9FF';

  // 装饰与微阴影
  static readonly glowBlue: string = 'rgba(37, 99, 235, 0.16)';
  static readonly cardShadow: string = 'rgba(15, 23, 42, 0.04)';
}
