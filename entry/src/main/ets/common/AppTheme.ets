/**
 * 鸿蒙智安参考图浅蓝校园安防设计令牌。
 *
 * 以参考图的浅蓝白为画布，以清晰的协同蓝构建信息秩序；
 * 红、绿、琥珀色仅用于具有明确业务含义的状态。
 */
export class AppTheme {
  // 画布与容器表面
  static readonly canvas: string = '#F4F8FF';
  static readonly surface: string = '#FFFFFF';
  static readonly surfaceMuted: string = '#EEF5FF';
  static readonly surfaceSubtle: string = '#DCEBFF';

  // 文字与排版层次
  static readonly ink: string = '#18243E';
  static readonly inkSoft: string = '#52617B';
  static readonly muted: string = '#8A97AF';
  static readonly line: string = '#E7EEF8';
  static readonly lineStrong: string = '#B6CDF0';

  // 核心安防主色与辅助色
  static readonly accent: string = '#1677FF';
  static readonly accentDark: string = '#2469FF';
  static readonly accentDeep: string = '#1755F5';
  static readonly accentSoft: string = '#E2EFFF';
  static readonly bronze: string = '#9A7337';
  static readonly bronzeSoft: string = '#F3E8D2';

  // 辅助状态色
  static readonly cyan: string = '#3B82F6';
  static readonly cyanSoft: string = '#E6F0FF';
  static readonly amber: string = '#FF941F';
  static readonly amberSoft: string = '#FAEFD9';
  static readonly danger: string = '#FF4F58';
  static readonly dangerSoft: string = '#F9E3E3';
  static readonly success: string = '#20BEA0';
  static readonly successSoft: string = '#E0F1EA';
  static readonly info: string = '#176B9C';
  static readonly infoSoft: string = '#DCEEF8';

  // 布局与微阴影
  static readonly radiusSmall: number = 8;
  static readonly radiusMedium: number = 12;
  static readonly radiusLarge: number = 16;
  static readonly pageInset: number = 20;
  static readonly sectionGap: number = 24;
  static readonly glowBlue: string = 'rgba(22, 119, 255, 0.18)';
  static readonly cardShadow: string = 'rgba(22, 82, 160, 0.10)';
}
