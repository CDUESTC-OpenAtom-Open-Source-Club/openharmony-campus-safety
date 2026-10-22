import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { CountdownEvent } from '../model/CountdownEvent';
import { CountdownService } from '../service/CountdownService';
import { AppTheme } from '../common/AppTheme';

interface CountdownPreset {
  label: string;
  name: string;
  tag: string;
  month: number;
  day: number;
}

@Component
export struct CountdownManagePage {
  pageStack: NavPathStack = new NavPathStack();
  onChanged: () => void = () => {};

  @State private events: CountdownEvent[] = [];
  @State private loading: boolean = true;
  @State private editorVisible: boolean = false;
  @State private deleteConfirmVisible: boolean = false;
  @State private editingId: string = '';
  @State private formName: string = '';
  @State private formDate: string = '';
  @State private formTag: string = '';
  @State private selectedDate: Date = new Date();
  @State private formTriedSave: boolean = false;
  @State private deleteTargetId: string = '';
  @State private deleteTargetName: string = '';

  private readonly presets: CountdownPreset[] = [
    { label: '英语四级 CET-4', name: '英语四级（CET-4）', tag: '笔试', month: 12, day: 19 },
    { label: '英语六级 CET-6', name: '英语六级（CET-6）', tag: '笔试', month: 12, day: 19 },
    { label: '考研初试', name: '考研初试', tag: '初试', month: 12, day: 19 },
    { label: '教师资格证笔试', name: '教师资格证笔试', tag: '笔试', month: 3, day: 14 },
    { label: '计算机二级', name: '计算机二级', tag: '等级考试', month: 3, day: 28 },
    { label: '期末考试周', name: '期末考试周', tag: '期末考试', month: 12, day: 21 }
  ];

  aboutToAppear(): void {
    this.loadEvents();
  }

  private async loadEvents(): Promise<void> {
    this.loading = true;
    try {
      this.events = await CountdownService.getEvents(getContext(this) as common.Context);
    } catch (error) {
      console.error('CountdownManagePage load failed: ' + JSON.stringify(error));
      promptAction.showToast({ message: '倒计时读取失败，请重试' });
    }
    this.loading = false;
  }

  private managedEvents(): CountdownEvent[] {
    return CountdownService.getManagementList(this.events);
  }

  private nextPresetDate(month: number, day: number): string {
    const now: Date = new Date();
    const today: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    let year: number = now.getFullYear();
    const candidate: Date = new Date(year, month - 1, day);
    if (candidate.getTime() < today.getTime()) {
      year += 1;
    }
    return CountdownService.toDateString(new Date(year, month - 1, day));
  }

  private applyPreset(preset: CountdownPreset): void {
    this.formName = preset.name;
    this.formTag = preset.tag;
    this.formDate = this.nextPresetDate(preset.month, preset.day);
    this.selectedDate = new Date(this.formDate + 'T00:00:00');
    this.formTriedSave = false;
  }

  private openAdd(): void {
    this.editingId = '';
    this.formName = '';
    this.selectedDate = new Date();
    this.formDate = CountdownService.toDateString(this.selectedDate);
    this.formTag = '';
    this.formTriedSave = false;
    this.editorVisible = true;
  }

  private openEdit(event: CountdownEvent): void {
    this.editingId = event.id;
    this.formName = event.name;
    this.formDate = event.date;
    this.formTag = event.tag;
    this.selectedDate = new Date(event.date + 'T00:00:00');
    this.formTriedSave = false;
    this.editorVisible = true;
  }

  private closeEditor(): void {
    this.editorVisible = false;
    this.formTriedSave = false;
  }

  private async saveEvent(): Promise<void> {
    this.formTriedSave = true;
    const name: string = this.formName.trim();
    const date: string = this.formDate.trim();
    const tag: string = this.formTag.trim();
    if (name.length === 0 || date.length === 0) {
      return;
    }
    if (name.length > 20 || tag.length > 8 || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      promptAction.showToast({ message: '请检查名称、日期或标签格式' });
      return;
    }

    let nextEvents: CountdownEvent[] = this.events.slice();
    if (this.editingId !== '') {
      nextEvents = nextEvents.map((event: CountdownEvent) => event.id === this.editingId ? {
        id: event.id,
        name: name,
        date: date,
        tag: tag
      } : event);
    } else {
      nextEvents = nextEvents.concat([{
        id: Date.now().toString(36),
        name: name,
        date: date,
        tag: tag
      }]);
    }

    try {
      await CountdownService.saveEvents(getContext(this) as common.Context, nextEvents);
      this.events = nextEvents;
      this.editorVisible = false;
      this.formTriedSave = false;
      this.onChanged();
      promptAction.showToast({ message: this.editingId === '' ? '倒计时已添加' : '倒计时已更新' });
    } catch (error) {
      console.error('CountdownManagePage save failed: ' + JSON.stringify(error));
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  private askDelete(event: CountdownEvent): void {
    this.deleteTargetId = event.id;
    this.deleteTargetName = event.name;
    this.deleteConfirmVisible = true;
  }

  private async confirmDelete(): Promise<void> {
    const nextEvents: CountdownEvent[] = this.events.filter((event: CountdownEvent) =>
    event.id !== this.deleteTargetId
    );
    try {
      await CountdownService.saveEvents(getContext(this) as common.Context, nextEvents);
      this.events = nextEvents;
      this.deleteConfirmVisible = false;
      this.onChanged();
      promptAction.showToast({ message: '已删除倒计时' });
    } catch (error) {
      console.error('CountdownManagePage delete failed: ' + JSON.stringify(error));
      promptAction.showToast({ message: '删除失败，请重试' });
    }
  }

  @Builder
  private countdownRow(event: CountdownEvent) {
    Row({ space: 10 }) {
      Column({ space: 5 }) {
        Text(event.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(CountdownService.formatDateLine(event))
          .fontSize(10.5)
          .fontColor('#9CA3AF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 2 }) {
        if (CountdownService.daysLeft(event.date) < 0) {
          Text('已结束')
            .fontSize(10)
            .fontColor('#9CA3AF')
        } else {
          Text(CountdownService.dayText(CountdownService.daysLeft(event.date)))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2563EB')
          if (CountdownService.daysLeft(event.date) > 1) {
            Text('天').fontSize(10).fontColor('#9CA3AF')
          }
        }
      }
      .width(42)
      .alignItems(HorizontalAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(13)
          .height(2.5)
          .borderRadius(2)
          .backgroundColor('#378ADD')
          .rotate({ angle: -45 })
      }
      .width(30)
      .height(30)
      .borderRadius(8)
      .backgroundColor('#E6F1FB')
      .onClick(() => this.openEdit(event))

      Column({ space: 2 }) {
        Row().width(10).height(1.5).borderRadius(1).backgroundColor('#D0655E')
        Row().width(9).height(9).border({ width: 1.2, color: '#D0655E' }).borderRadius(2)
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(8)
      .backgroundColor('#FFF1F0')
      .onClick(() => this.askDelete(event))
    }
    .width('100%')
    .padding({ left: 12, right: 10, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(13)
    .border({ width: 1, color: '#E9F0F8' })
  }

  @Builder
  private presetChip(preset: CountdownPreset) {
    Text(preset.label)
      .fontSize(11)
      .fontColor('#185FA5')
      .padding({ left: 11, right: 11, top: 8, bottom: 8 })
      .borderRadius(15)
      .backgroundColor('#E6F1FB')
      .onClick(() => this.applyPreset(preset))
  }

  @Builder
  private editorSheet() {
    Column() {
      Row() {
        Text(this.editingId === '' ? '添加考试 / 时间点' : '编辑倒计时')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
        Blank()
        Text('取消')
          .fontSize(13)
          .fontColor(AppTheme.muted)
          .padding(6)
          .onClick(() => this.closeEditor())
      }
      .width('100%')

      Scroll() {
        Column({ space: 8 }) {
          Text('快速填入（预设日期仅供参考）')
            .fontSize(11)
            .fontColor(AppTheme.muted)
            .width('100%')

          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.presets, (preset: CountdownPreset) => {
                this.presetChip(preset)
              })
            }
          }
          .width('100%')
          .height(38)
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)

          Text('名称（必填，最多 20 字）')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .width('100%')
          TextInput({ placeholder: '例如：英语四级（CET-4）', text: this.formName })
            .fontSize(13)
            .height(42)
            .maxLength(20)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F7FAFE')
            .border({ width: 1, color: this.formTriedSave && this.formName.trim() === '' ? '#D0655E' : '#E2EAF4' })
            .borderRadius(10)
            .onChange((value: string) => {
              this.formName = value.slice(0, 20);
            })
          if (this.formTriedSave && this.formName.trim() === '') {
            Text('请填写事件名称').fontSize(10).fontColor('#D0655E').width('100%')
          }

          Text('日期（必填）')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .width('100%')
          Text(this.formDate === '' ? '请选择目标日期' : this.formDate)
            .fontSize(13)
            .fontColor(this.formDate === '' ? '#9CA3AF' : '#1F2937')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .width('100%')
            .backgroundColor('#F7FAFE')
            .border({ width: 1, color: this.formTriedSave && this.formDate === '' ? '#D0655E' : '#E2EAF4' })
            .borderRadius(10)
          DatePicker({
            start: new Date(2024, 0, 1),
            end: new Date(2100, 11, 31),
            selected: this.selectedDate
          })
            .height(142)
            .width('100%')
            .onChange((value: DatePickerResult) => {
              this.selectedDate = new Date(
                value.year ?? this.selectedDate.getFullYear(),
                value.month ?? this.selectedDate.getMonth(),
                value.day ?? this.selectedDate.getDate()
              );

              this.formDate = CountdownService.toDateString(this.selectedDate);
            })
          if (this.formTriedSave && this.formDate === '') {
            Text('请选择目标日期').fontSize(10).fontColor('#D0655E').width('100%')
          }

          Text('标签（选填，最多 8 字）')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .width('100%')
          TextInput({ placeholder: '例如：笔试、期末考试', text: this.formTag })
            .fontSize(13)
            .height(42)
            .maxLength(8)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F7FAFE')
            .border({ width: 1, color: '#E2EAF4' })
            .borderRadius(10)
            .onChange((value: string) => {
              this.formTag = value.slice(0, 8);
            })

          Text('考试日期可能调整，预设日期请以官方通知为准。')
            .fontSize(10)
            .fontColor('#9CA3AF')
            .width('100%')
            .margin({ top: 2 })
        }
        .width('100%')
        .padding({ top: 14, bottom: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Row({ space: 10 }) {
        Text('取消')
          .fontSize(13)
          .fontColor(AppTheme.inkSoft)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('#F1F5F9')
          .borderRadius(12)
          .onClick(() => this.closeEditor())
        Text('保存')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('#185FA5')
          .borderRadius(12)
          .onClick(() => this.saveEvent())
      }
      .width('100%')
    }
    .width('100%')
    .height('86%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 20, topRight: 20, bottomLeft: 0, bottomRight: 0 })
  }

  @Builder
  private deleteConfirmSheet() {
    Column() {
      Column({ space: 12 }) {
        Text('确定删除吗？')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)
          .width('100%')
        Text('删除后将无法恢复「' + this.deleteTargetName + '」，确定要删除这个倒计时吗？')
          .fontSize(12)
          .fontColor(AppTheme.muted)
          .lineHeight(18)
          .width('100%')
        Row({ space: 10 }) {
          Text('取消')
            .fontSize(13)
            .fontColor(AppTheme.inkSoft)
            .layoutWeight(1)
            .height(42)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F1F5F9')
            .borderRadius(10)
            .onClick(() => this.deleteConfirmVisible = false)
          Text('删除')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
            .height(42)
            .textAlign(TextAlign.Center)
            .backgroundColor('#D0655E')
            .borderRadius(10)
            .onClick(() => this.confirmDelete())
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .margin({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(15, 23, 42, 0.35)')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('‹')
            .fontSize(28)
            .fontColor(AppTheme.inkSoft)
            .padding({ left: 4, right: 12 })
            .onClick(() => this.pageStack.pop())
          Column({ space: 2 }) {
            Text('管理倒计时')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
            Text('考试、测验与重要时间点')
              .fontSize(10)
              .fontColor(AppTheme.muted)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
        }
        .width('100%')
        .padding({ left: 14, right: 16, top: 14, bottom: 12 })
        .backgroundColor(AppTheme.surface)
        .border({ width: { bottom: 1 }, color: AppTheme.line })

        Scroll() {
          Column({ space: 10 }) {
            if (this.loading) {
              Text('正在读取倒计时…')
                .fontSize(12)
                .fontColor(AppTheme.muted)
                .padding(24)
            } else if (this.events.length === 0) {
              Column({ space: 8 }) {
                Text('还没有添加倒计时')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.ink)
                Text('添加考试日期或其他重要时间点，首页会自动显示最近的 4 条。')
                  .fontSize(11)
                  .fontColor(AppTheme.muted)
                  .textAlign(TextAlign.Center)
                Text('＋ 添加第一个倒计时')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .padding({ left: 18, right: 18, top: 10, bottom: 10 })
                  .borderRadius(20)
                  .backgroundColor('#185FA5')
                  .margin({ top: 4 })
                  .onClick(() => this.openAdd())
              }
              .width('100%')
              .padding(24)
              .borderRadius(15)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E1EAF5', style: BorderStyle.Dashed })
            } else {
              ForEach(this.managedEvents(), (event: CountdownEvent) => {
                this.countdownRow(event)
              })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 16 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)

        Text('＋ 添加考试 / 时间点')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('100%')
          .height(46)
          .textAlign(TextAlign.Center)
          .borderRadius(13)
          .backgroundColor('#185FA5')
          .shadow({ radius: 8, color: 'rgba(24, 95, 165, 0.18)', offsetY: 3 })
          .margin({ left: 16, right: 16, top: 8, bottom: 16 })
          .onClick(() => this.openAdd())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.canvas)

      if (this.editorVisible) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.closeEditor())
          this.editorSheet()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(15, 23, 42, 0.35)')
      }

      if (this.deleteConfirmVisible) {
        this.deleteConfirmSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.canvas)
  }
}
