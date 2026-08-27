import { EventType } from '../model/SecurityEvent';
import { EventWorkflowService } from '../service/EventWorkflowService';
import { promptAction } from '@kit.ArkUI';

/**
 * 隐患上报页（B 端页面，C 按授权修复"提交隐患"无响应问题）
 *
 * 数据流：B 表单与交互 → C 的 EventWorkflowService.reportHazard 数据转换与事件生成 → EventRepository 落库。
 * 必填项（发生地点 / 隐患描述）为空时提交返回 undefined，页面给出提示。
 */
@Component
export struct ReportPage {
  @State selectedTypeIndex: number = 0;
  @State location: string = '';
  @State description: string = '';
  @State reporter: string = '';

  // 并行数组：下标与 Select 选项一一对应，避免类型强转
  private typeValues: EventType[] = [
    EventType.FIRE,
    EventType.ELECTRIC,
    EventType.FACILITY,
    EventType.CAMPUS,
    EventType.OTHER
  ];
  private typeOptions: SelectOption[] = [
    { value: EventType.FIRE },
    { value: EventType.ELECTRIC },
    { value: EventType.FACILITY },
    { value: EventType.CAMPUS },
    { value: EventType.OTHER }
  ];

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text('隐患上报')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)

        Text('校园安全隐患上报')
          .fontSize(18)

        // 隐患类型
        Row() {
          Text('隐患类型')
            .fontSize(16)
            .width(80)
          Select(this.typeOptions)
            .selected(this.selectedTypeIndex)
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.selectedTypeIndex = index;
            })
        }
        .width('100%')

        // 发生地点（必填）
        Row() {
          Text('发生地点')
            .fontSize(16)
            .width(80)
          TextInput({ placeholder: '请输入发生地点', text: this.location })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.location = value;
            })
        }
        .width('100%')

        // 隐患描述（必填）
        Column() {
          Text('隐患描述')
            .fontSize(16)
            .width('100%')
          TextArea({ placeholder: '请描述隐患情况', text: this.description })
            .width('100%')
            .height(120)
            .onChange((value: string) => {
              this.description = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 上报人（选填）
        Row() {
          Text('上报人')
            .fontSize(16)
            .width(80)
          TextInput({ placeholder: '选填', text: this.reporter })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.reporter = value;
            })
        }
        .width('100%')

        Button('提交隐患')
          .width('60%')
          .height(50)
          .margin({ top: 20 })
          .onClick(() => {
            const result = EventWorkflowService.reportHazard({
              // 标题由隐患描述自动派生（前15字+省略号），无需学生单独填写；空描述时返回占位标题，
              // 但 reportHazard 的必填校验仍会拦截空描述返回 undefined，下方 toast 提示不变
              title: EventWorkflowService.buildSummaryTitle(this.description),
              type: this.typeValues[this.selectedTypeIndex],
              location: this.location,
              description: this.description,
              reporter: this.reporter
            });
            if (result === undefined) {
              promptAction.showToast({ message: '请填写发生地点和隐患描述' });
            } else {
              promptAction.showToast({ message: '提交成功：' + result.id });
              // 清空表单，便于连续上报
              this.location = '';
              this.description = '';
              this.reporter = '';
            }
          })
      }
      .width('100%')
      .height('100%')
      .padding(16)
    }
    .title('隐患上报')
  }
}
