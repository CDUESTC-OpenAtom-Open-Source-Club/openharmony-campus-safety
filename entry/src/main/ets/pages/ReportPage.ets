import {
  EventType,
  EventPriority
} from '../model/SecurityEvent';
import { EventWorkflowService } from '../service/EventWorkflowService';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AttachmentService } from '../service/AttachmentService';
import { AppTheme } from '../common/AppTheme';

interface TypeCard {
  type: EventType;
  label: string;
  tag: string;
  color: string;
  bg: string;
}

@Component
export struct ReportPage {
  pageStack: NavPathStack = new NavPathStack();
  onReported: () => void = () => {};

  @State private pageReady: boolean = false;
  @State private selectedTypeIndex: number = 0;
  @State private selectedPriorityIndex: number = 1;
  @State private location: string = '';
  @State private description: string = '';
  @State private reporter: string = '';
  @State private attachmentPaths: string[] = [];

  private typeCards: TypeCard[] = [
    { type: EventType.FIRE, label: '消防安全', tag: 'FIRE', color: '#DC2626', bg: '#FEF2F2' },
    { type: EventType.ELECTRIC, label: '电气线路', tag: 'ELEC', color: '#D97706', bg: '#FFFBEB' },
    { type: EventType.FACILITY, label: '公共设施', tag: 'EQPT', color: '#2563EB', bg: '#EFF6FF' },
    { type: EventType.CAMPUS, label: '校园秩序', tag: 'SAFE', color: '#059669', bg: '#ECFDF5' },
    { type: EventType.OTHER, label: '其他事件', tag: 'MISC', color: '#475569', bg: '#F1F5F9' }
  ];

  private quickLocations: string[] = [
    '品学楼 B 栋 3 楼',
    '立人楼 A 栋 2 楼',
    '第12学生宿舍',
    '北区第一食堂',
    '东区体育馆'
  ];

  private priorityValues: EventPriority[] = [
    EventPriority.URGENT,
    EventPriority.HIGH,
    EventPriority.MEDIUM,
    EventPriority.LOW
  ];

  private selectPhotos(): void {
    const context: common.Context = getContext(this) as common.Context;
    AttachmentService.selectEvidence(context).then((paths: string[]) => {
      if (paths.length === 0) {
        promptAction.showToast({ message: '未选择照片或照片超过 10 MB' });
        return;
      }
      this.attachmentPaths.forEach((path: string) => AttachmentService.remove(path));
      this.attachmentPaths = paths;
    }).catch((error: Error) => {
      promptAction.showToast({ message: '照片选择失败：' + error.message });
    });
  }

  private submit(): void {
    if (this.location.trim() === '' || this.description.trim() === '') {
      promptAction.showToast({ message: '请填写发生地点和隐患描述' });
      return;
    }
    const result = EventWorkflowService.reportHazard({
      title: EventWorkflowService.buildSummaryTitle(this.description),
      type: this.typeCards[this.selectedTypeIndex].type,
      location: this.location,
      description: this.description,
      reporter: this.reporter,
      priority: this.priorityValues[this.selectedPriorityIndex],
      attachmentPaths: this.attachmentPaths
    });
    if (result === undefined) {
      promptAction.showToast({ message: '请填写发生地点和隐患描述' });
    } else {
      promptAction.showToast({ message: '上报成功！编号：' + result.id });
      this.onReported();
      this.location = '';
      this.description = '';
      this.reporter = '';
      this.attachmentPaths = [];
    }
  }

  @Builder
  sectionHeader(title: string, required: boolean, note: string) {
    Row() {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.ink)
      if (required) {
        Text('*')
          .fontSize(12)
          .fontColor(AppTheme.danger)
          .margin({ left: 2 })
      }
      if (note !== '') {
        Text(note)
          .fontSize(10)
          .fontColor(AppTheme.muted)
          .margin({ left: 6 })
      }
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.inkSoft)
          .padding({ left: 4, right: 10 })
          .onClick(() => {
            this.pageStack.pop();
          })

        Column({ space: 2 }) {
          Text('隐患上报')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)

          Text('随手拍隐患 · 师生共建平安校园')
            .fontSize(10)
            .fontColor(AppTheme.muted)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 4 }) {
          Image($r('app.media.ic_report'))
            .width(16)
            .height(16)
            .fillColor(AppTheme.accent)
          Text('安全协同')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.accent)
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .borderRadius(12)
        .backgroundColor(AppTheme.accentSoft)
        .border({ width: 1, color: AppTheme.cyanSoft })
      }
      .width('100%')
      .padding({ left: 14, right: 16, top: 14, bottom: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { bottom: 1 }, color: AppTheme.line })

      Scroll() {
        Column({ space: 12 }) {
          // 隐患类型选择
          Column() {
            this.sectionHeader('隐患类型选择', true, '')
            Row({ space: 8 }) {
              ForEach(this.typeCards.slice(0, 3), (item: TypeCard, index: number) => {
                this.typeCell(item, index)
              }, (item: TypeCard) => item.type)
            }
            .width('100%')
            Row({ space: 8 }) {
              ForEach(this.typeCards.slice(3, 5), (item: TypeCard, index: number) => {
                this.typeCell(item, index + 3)
              }, (item: TypeCard) => item.type)
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })

          // 隐患等级
          Column({ space: 8 }) {
            Row() {
              Text('隐患等级')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
              Text('（用于评估处置优先级）')
                .fontSize(10)
                .fontColor(AppTheme.muted)
                .margin({ left: 6 })
            }
            .width('100%')

            Row({ space: 8 }) {
              ForEach(this.priorityValues, (priority: EventPriority, index: number) => {
                Text(priority)
                  .fontSize(11)
                  .fontWeight(this.selectedPriorityIndex === index ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.selectedPriorityIndex === index ? Color.White : AppTheme.inkSoft)
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .borderRadius(12)
                  .backgroundColor(
                    this.selectedPriorityIndex === index
                      ? (priority === EventPriority.URGENT || priority === EventPriority.HIGH ? AppTheme.danger : AppTheme.accent)
                      : AppTheme.surfaceMuted
                  )
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.selectedPriorityIndex = index;
                  })
              }, (priority: EventPriority) => priority)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })

          // 发生地点
          Column({ space: 8 }) {
            this.sectionHeader('发生具体地点', true, '')
            TextInput({
              placeholder: '请输入发生地点',
              text: this.location
            })
              .width('100%')
              .height(42)
              .fontSize(12)
              .borderRadius(12)
              .backgroundColor(AppTheme.surfaceMuted)
              .border({ width: 1, color: AppTheme.line })
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.location = value;
              })

            Scroll() {
              Row({ space: 6 }) {
                Text('快捷输入')
                  .fontSize(10)
                  .fontColor(AppTheme.muted)
                ForEach(this.quickLocations, (loc: string) => {
                  Text(loc)
                    .fontSize(10)
                    .fontColor(AppTheme.inkSoft)
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .borderRadius(10)
                    .backgroundColor(AppTheme.surfaceMuted)
                    .border({ width: 1, color: AppTheme.line })
                    .onClick(() => {
                      this.location = loc;
                    })
                }, (loc: string) => loc)
              }
              .width('100%')
            }
            .width('100%')
            .scrollBar(BarState.Off)
            .scrollable(ScrollDirection.Horizontal)
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })

          // 隐患描述
          Column({ space: 8 }) {
            this.sectionHeader('详细隐患情况', true, '')
            TextArea({
              placeholder: '请详细说明现场隐患现象',
              text: this.description
            })
              .width('100%')
              .height(96)
              .fontSize(12)
              .borderRadius(12)
              .backgroundColor(AppTheme.surfaceMuted)
              .border({ width: 1, color: AppTheme.line })
              .padding(12)
              .onChange((value: string) => {
                this.description = value;
              })
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })

          // 现场照片与上报人
          Column({ space: 12 }) {
            Column({ space: 6 }) {
              Text('现场证据照片')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ink)
                .width('100%')

              if (this.attachmentPaths.length > 0) {
                Column({ space: 8 }) {
                  ForEach(this.attachmentPaths, (path: string) => {
                    Row({ space: 10 }) {
                      Image('file://' + path)
                        .width(58)
                        .height(58)
                        .borderRadius(10)
                        .objectFit(ImageFit.Cover)
                        .border({ width: 1, color: AppTheme.line })
                      Text('已保存到应用私有目录')
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.accent)
                        .layoutWeight(1)
                      Text('移除')
                        .fontSize(10)
                        .fontColor(AppTheme.danger)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .borderRadius(8)
                        .backgroundColor(AppTheme.dangerSoft)
                        .onClick(() => {
                          AttachmentService.remove(path);
                          this.attachmentPaths = this.attachmentPaths.filter((item: string) => item !== path);
                        })
                    }
                    .width('100%')
                  }, (path: string) => path)
                  Text('重新选择')
                    .fontSize(11)
                    .fontColor(AppTheme.accent)
                    .onClick(() => this.selectPhotos())
                }
                .width('100%')
                .padding(10)
                .borderRadius(14)
                .backgroundColor(AppTheme.accentSoft)
                .border({ width: 1, color: AppTheme.cyanSoft })
              } else {
                Column({ space: 6 }) {
                  Image($r('app.media.ic_report'))
                    .width(24)
                    .height(24)
                    .fillColor(AppTheme.muted)
                  Text('点击从系统相册选择照片（最多 3 张）')
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.muted)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .height(76)
                .borderRadius(14)
                .border({ width: 1, color: AppTheme.lineStrong })
                .borderStyle(BorderStyle.Dashed)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.selectPhotos();
                })
              }
            }
            .width('100%')

            Column({ space: 6 }) {
              Row() {
                Text('上报人姓名/电话')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.ink)
                Text('（选填）')
                  .fontSize(10)
                  .fontColor(AppTheme.muted)
                  .margin({ left: 6 })
              }
              .width('100%')

              TextInput({
                placeholder: '留空则默认为匿名上报',
                text: this.reporter
              })
                .width('100%')
                .height(42)
                .fontSize(12)
                .borderRadius(12)
                .backgroundColor(AppTheme.surfaceMuted)
                .border({ width: 1, color: AppTheme.line })
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.reporter = value;
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })

          // 提交按钮
          Button('立即提交隐患')
            .width('100%')
            .height(48)
            .borderRadius(14)
            .backgroundColor(AppTheme.accent)
            .fontColor(Color.White)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .shadow({ radius: 12, color: AppTheme.glowBlue, offsetY: 4 })
            .margin({ top: 4, bottom: 20 })
            .onClick(() => {
              this.submit();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.canvas)
    .opacity(this.pageReady ? 1 : 0)
    .translate({ y: this.pageReady ? 0 : 18 })
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear(() => {
      this.pageReady = true;
    })
  }

  @Builder
  typeCell(item: TypeCard, index: number) {
    Column({ space: 4 }) {
      Text(item.tag)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedTypeIndex === index ? '#93C5FD' : item.color)
        .letterSpacing(0.5)

      Text(item.label)
        .fontSize(12)
        .fontWeight(this.selectedTypeIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTypeIndex === index ? Color.White : AppTheme.ink)
    }
    .layoutWeight(1)
    .height(64)
    .borderRadius(14)
    .backgroundColor(
      this.selectedTypeIndex === index ? AppTheme.accent : item.bg
    )
    .border({
      width: 1,
      color: this.selectedTypeIndex === index ? AppTheme.accentDark : AppTheme.line
    })
    .shadow({
      radius: this.selectedTypeIndex === index ? 8 : 0,
      color: AppTheme.glowBlue,
      offsetY: 2
    })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectedTypeIndex = index;
    })
  }
}
