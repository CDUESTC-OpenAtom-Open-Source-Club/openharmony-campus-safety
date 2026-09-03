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

  /* 【不可改】并行数组与 SelectOption 逐字保留 */
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
    /* 【不可改】外层 NavDestination(){...}.title('隐患上报') 结构必须保留（当前工程就是双层 NavDestination 嵌套且可运行，不要"好心"去掉） */
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          // 头部引导卡片
          Column() {
            Text('隐患上报')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
              .margin({ bottom: 4 })

            Text('校园安全隐患上报 · 共同守护师生安全')
              .fontSize(13)
              .fontColor('#64748B')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 6 })

          // 表单容器卡片
          Column({ space: 16 }) {
            // 1. 隐患类型选择
            Column({ space: 6 }) {
              Row() {
                Text('隐患类型')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#334155')

                Text(' *')
                  .fontSize(14)
                  .fontColor('#EF4444')
              }
              .width('100%')

              Select(this.typeOptions)
                .selected(this.selectedTypeIndex)
                .value(this.typeOptions[this.selectedTypeIndex].value)
                .width('100%')
                .height(44)
                .borderRadius(10)
                .backgroundColor('#F8FAFC')
                .border({ width: 1, color: '#E2E8F0' })
                .font({ size: 14 })
                .onSelect((index: number) => {
                  this.selectedTypeIndex = index;
                })
            }
            .width('100%')

            // 2. 发生地点输入
            Column({ space: 6 }) {
              Row() {
                Text('发生地点')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#334155')

                Text(' *')
                  .fontSize(14)
                  .fontColor('#EF4444')
              }
              .width('100%')

              TextInput({
                placeholder: '例如：图书馆二楼东侧走廊 / 3号宿舍楼插座',
                text: this.location
              })
                .width('100%')
                .height(44)
                .borderRadius(10)
                .backgroundColor('#F8FAFC')
                .border({ width: 1, color: '#E2E8F0' })
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.location = value;
                })
            }
            .width('100%')

            // 3. 隐患描述
            Column({ space: 6 }) {
              Row() {
                Text('隐患描述')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#334155')

                Text(' *')
                  .fontSize(14)
                  .fontColor('#EF4444')
              }
              .width('100%')

              TextArea({
                placeholder: '请详细描述现场异常现象，如漏水严重程度、电火花或堵塞通道等情况...',
                text: this.description
              })
                .width('100%')
                .height(110)
                .borderRadius(10)
                .backgroundColor('#F8FAFC')
                .border({ width: 1, color: '#E2E8F0' })
                .padding(12)
                .onChange((value: string) => {
                  this.description = value;
                })
            }
            .width('100%')

            // 4. 上报人 (选填)
            Column({ space: 6 }) {
              Row() {
                Text('上报人')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#334155')

                Text(' (选填)')
                  .fontSize(12)
                  .fontColor('#94A3B8')
              }
              .width('100%')

              TextInput({
                placeholder: '填写姓名或留空匿名上报',
                text: this.reporter
              })
                .width('100%')
                .height(44)
                .borderRadius(10)
                .backgroundColor('#F8FAFC')
                .border({ width: 1, color: '#E2E8F0' })
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.reporter = value;
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })

          // 提交按钮
          Button('提交隐患')
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#1B6EFF')
            .fontWeight(FontWeight.Bold)
            .shadow({ radius: 12, color: 'rgba(27, 110, 255, 0.25)', offsetY: 4 })
            .margin({ top: 8, bottom: 20 })
            .onClick(() => {
              const result = EventWorkflowService.reportHazard({
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
                this.location = '';
                this.description = '';
                this.reporter = '';
              }
            })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')
    }
    .title('隐患上报')
  }
}
