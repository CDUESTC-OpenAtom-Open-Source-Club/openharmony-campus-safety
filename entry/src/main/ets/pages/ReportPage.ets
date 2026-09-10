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
    { type: EventType.FIRE, label: '消防安全', tag: 'FIRE', color: AppTheme.danger, bg: AppTheme.dangerSoft },
    { type: EventType.ELECTRIC, label: '电气线路', tag: 'ELEC', color: AppTheme.amber, bg: AppTheme.amberSoft },
    { type: EventType.FACILITY, label: '公共设施', tag: 'EQPT', color: AppTheme.accent, bg: AppTheme.accentSoft },
    { type: EventType.CAMPUS, label: '校园秩序', tag: 'SAFE', color: AppTheme.success, bg: AppTheme.successSoft },
    { type: EventType.OTHER, label: '其他事件', tag: 'MISC', color: AppTheme.inkSoft, bg: AppTheme.surfaceMuted }
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
      Row() {
        Text('‹').fontSize(30).fontColor(AppTheme.ink).width(44).height(48)
          .onClick(() => { this.pageStack.pop(); })
        Text('隐患上报').fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(44)
      }.width('100%').height(52).padding({ left: 16, right: 16 }).backgroundColor(AppTheme.canvas)


      Scroll() {
        Column({ space: 20 }) {
          Column() {
            this.sectionHeader('隐患类型', true, '')
            Select([{ value: '消防安全' }, { value: '电气线路' }, { value: '公共设施' }, { value: '校园秩序' }, { value: '其他事件' }])
              .selected(this.selectedTypeIndex).value(this.typeCards[this.selectedTypeIndex].label)
              .width('100%').height(44).font({ size: 13 }).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
              .onSelect((index: number) => { this.selectedTypeIndex = index; })
          }.width('100%')
          Column() {
            this.sectionHeader('具体位置', true, '')
            TextInput({ placeholder: '请输入隐患所在位置', text: this.location }).height(44).fontSize(13)
              .backgroundColor(AppTheme.surfaceMuted).borderRadius(8).onChange((value: string) => { this.location = value; })
          }.width('100%')
          Column() {
            this.sectionHeader('详细描述', true, '')
            TextArea({ placeholder: '请详细描述发现的安全隐患情况…', text: this.description })
              .height(112).fontSize(13).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
              .onChange((value: string) => { this.description = value; })
          }.width('100%')
          Column() {
            this.sectionHeader('风险等级', true, '')
            Row({ space: 8 }) {
              ForEach(this.priorityValues, (priority: EventPriority, index: number) => {
                Text(priority).fontSize(13).height(40).layoutWeight(1).textAlign(TextAlign.Center)
                  .fontColor(index === this.selectedPriorityIndex ? AppTheme.accent : AppTheme.inkSoft)
                  .backgroundColor(index === this.selectedPriorityIndex ? AppTheme.accentSoft : AppTheme.surfaceMuted)
                  .borderRadius(8).border({ width: 1, color: index === this.selectedPriorityIndex ? AppTheme.accent : AppTheme.line })
                  .onClick(() => { this.selectedPriorityIndex = index; })
              }, (priority: EventPriority) => priority)
            }.width('100%')
          }.width('100%')
          Column() {
            this.sectionHeader('上传照片', false, '最多 3 张 · 点击照片移除')
            Row({ space: 8 }) {
              ForEach(this.attachmentPaths, (path: string) => {
                Image('file://' + path).width(64).height(72).objectFit(ImageFit.Cover).borderRadius(8)
                  .onClick(() => {
                    AttachmentService.remove(path);
                    this.attachmentPaths = this.attachmentPaths.filter((item: string) => item !== path);
                  })
              }, (path: string) => path)
              Text(this.attachmentPaths.length > 0 ? '重选' : '＋').fontSize(22).fontColor(AppTheme.muted)
                .width(64).height(72).textAlign(TextAlign.Center).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
                .onClick(() => this.selectPhotos())
            }.width('100%')
          }.width('100%')
          Column() {
            this.sectionHeader('联系人', false, '选填')
            TextInput({ placeholder: '请输入姓名或联系电话', text: this.reporter }).height(44).fontSize(13)
              .backgroundColor(AppTheme.surfaceMuted).borderRadius(8).onChange((value: string) => { this.reporter = value; })
          }.width('100%')
        }.width('100%').padding(18).backgroundColor(AppTheme.surface).borderRadius(14)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).padding({ left: 14, right: 14 })
      Button('提交上报').width('92%').height(48).fontSize(15).fontColor(Color.White)
        .linearGradient({ angle: 90, colors: [['#329DFF', 0], ['#1677FF', 1]] }).borderRadius(24)
        .margin({ top: 10, bottom: 10 }).onClick(() => this.submit())
    }.width('100%').height('100%').backgroundColor(AppTheme.canvas)
  }
}
