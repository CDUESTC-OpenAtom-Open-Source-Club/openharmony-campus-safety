import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { Course, CourseColor } from '../model/Course';
import { ScheduleService } from '../service/ScheduleService';
import { AppTheme } from '../common/AppTheme';

@Component
export struct StudentSchedulePage {
  @Link showSchedulePage: boolean;

  @State private courses: Course[] = [];
  @State private editorVisible: boolean = false;
  @State private editingId: string = '';
  @State private formName: string = '';
  @State private formLocation: string = '';
  @State private formWeekday: number = 1;
  @State private formStartPeriod: number = 1;
  @State private formEndPeriod: number = 2;
  @State private formColor: CourseColor = CourseColor.BLUE;
  @State private loading: boolean = true;

  private readonly weekdays: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  private readonly periods: number[] = [1, 2, 3, 4, 5, 6, 7, 8];
  private readonly periodTimes: string[][] = [
    ['08:15', '09:00'], ['09:05', '09:50'], ['10:05', '10:50'], ['10:55', '11:40'],
    ['14:00', '14:45'], ['14:50', '15:35'], ['15:50', '16:35'], ['16:40', '17:25']
  ];

  aboutToAppear(): void {
    ScheduleService.getCourses(getContext(this) as common.Context).then((items: Course[]) => {
      this.courses = items;
      this.loading = false;
    }).catch((error: Error) => {
      console.error('ScheduleService load failed: ' + error.message);
      this.loading = false;
      promptAction.showToast({ message: '课表读取失败' });
    });
  }

  private async persist(): Promise<void> {
    await ScheduleService.saveCourses(getContext(this) as common.Context, this.courses);
  }

  private getCurrentWeekday(): number {
    const day: number = new Date().getDay();
    return day === 0 ? 7 : day;
  }

  private courseAt(weekday: number, period: number): Course | undefined {
    return this.courses.find((course: Course) =>
      course.weekday === weekday && course.startPeriod === period
    );
  }

  private courseCovering(weekday: number, period: number): boolean {
    return this.courses.some((course: Course) =>
      course.weekday === weekday && course.startPeriod < period && course.endPeriod >= period
    );
  }

  private bg(color: CourseColor): string {
    switch (color) {
      case CourseColor.BLUE: return AppTheme.accentSoft;
      case CourseColor.GREEN: return AppTheme.successSoft;
      case CourseColor.RED: return AppTheme.dangerSoft;
      case CourseColor.ORANGE: return AppTheme.amberSoft;
      case CourseColor.PURPLE: return AppTheme.cyanSoft;
      default: return AppTheme.surfaceMuted;
    }
  }

  private fg(color: CourseColor): string {
    switch (color) {
      case CourseColor.BLUE: return AppTheme.accent;
      case CourseColor.GREEN: return AppTheme.success;
      case CourseColor.RED: return AppTheme.danger;
      case CourseColor.ORANGE: return AppTheme.amber;
      case CourseColor.PURPLE: return AppTheme.cyan;
      default: return AppTheme.inkSoft;
    }
  }

  private openAdd(): void {
    this.editingId = '';
    this.formName = '';
    this.formLocation = '';
    this.formWeekday = 1;
    this.formStartPeriod = 1;
    this.formEndPeriod = 2;
    this.formColor = CourseColor.BLUE;
    this.editorVisible = true;
  }

  private openEdit(course: Course): void {
    this.editingId = course.id;
    this.formName = course.name;
    this.formLocation = course.location;
    this.formWeekday = course.weekday;
    this.formStartPeriod = course.startPeriod;
    this.formEndPeriod = course.endPeriod;
    this.formColor = course.color;
    this.editorVisible = true;
  }

  private async removeCourse(id: string): Promise<void> {
    this.courses = this.courses.filter((course: Course) => course.id !== id);
    try {
      await this.persist();
      promptAction.showToast({ message: '课程已删除' });
    } catch (error) {
      promptAction.showToast({ message: '删除失败' });
    }
  }

  private async saveForm(): Promise<void> {
    const name: string = this.formName.trim();
    const location: string = this.formLocation.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请填写课程名称' });
      return;
    }
    if (location.length === 0) {
      promptAction.showToast({ message: '请填写上课地点' });
      return;
    }
    if (this.formEndPeriod < this.formStartPeriod) {
      promptAction.showToast({ message: '结束节次不能早于开始节次' });
      return;
    }

    const times: string[] = this.formStartPeriod === this.formEndPeriod
      ? this.periodTimes[this.formStartPeriod - 1]
      : [this.periodTimes[this.formStartPeriod - 1][0], this.periodTimes[this.formEndPeriod - 1][1]];

    if (this.editingId !== '') {
      this.courses = this.courses.map((course: Course) => {
        if (course.id !== this.editingId) {
          return course;
        }
        return {
          id: course.id,
          name,
          location,
          weekday: this.formWeekday,
          startPeriod: this.formStartPeriod,
          endPeriod: this.formEndPeriod,
          startTime: times[0],
          endTime: times[1],
          color: this.formColor
        };
      });
    } else {
      const newCourse: Course = {
        id: 'course_' + Date.now().toString(),
        name,
        location,
        weekday: this.formWeekday,
        startPeriod: this.formStartPeriod,
        endPeriod: this.formEndPeriod,
        startTime: times[0],
        endTime: times[1],
        color: this.formColor
      };
      this.courses = this.courses.concat([newCourse]);
    }

    try {
      await this.persist();
      this.editorVisible = false;
      promptAction.showToast({ message: '课表已保存' });
    } catch (error) {
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  private selectPeriodLabel(period: number): string {
    return period.toString();
  }

  @Builder
  topBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor(AppTheme.inkSoft)
        .padding({ left: 4, right: 10 })
        .onClick(() => { this.showSchedulePage = false; })

      Column({ space: 2 }) {
        Text('学生课表')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ink)

        Text('个人日常学业作息与安全联动')
          .fontSize(10)
          .fontColor(AppTheme.muted)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row({ space: 4 }) {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(AppTheme.info)
        Text('添加课程')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.accent)
      }
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .borderRadius(12)
      .backgroundColor(AppTheme.accentSoft)
      .border({ width: 1, color: AppTheme.cyanSoft })
      .onClick(() => this.openAdd())
    }
    .width('100%')
    .padding({ left: 14, right: 16, top: 14, bottom: 12 })
    .backgroundColor(AppTheme.surface)
    .border({ width: { bottom: 1 }, color: AppTheme.line })
  }

  @Builder
  weekHeader() {
    Row() {
      Column() {
        Text('本').fontSize(11).fontColor(AppTheme.muted)
        Text('周').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.ink).margin({ top: 2, bottom: 2 })
        Text('课表').fontSize(11).fontColor(AppTheme.muted)
      }
      .width(48)
      .height(70)
      .justifyContent(FlexAlign.Center)
      .borderRadius(14)
      .backgroundColor(AppTheme.surfaceMuted)
      .border({ width: 1, color: AppTheme.line })

      ForEach(this.weekdays, (day: string, index: number) => {
        Column({ space: 4 }) {
          Text(day)
            .fontSize(12)
            .fontColor(index + 1 === this.getCurrentWeekday() ? AppTheme.accent : AppTheme.inkSoft)
            .textAlign(TextAlign.Center)
            .width('100%')
            .fontWeight(index + 1 === this.getCurrentWeekday() ? FontWeight.Bold : FontWeight.Normal)
          Text(index + 1 === this.getCurrentWeekday() ? '今天' : '')
            .fontSize(9)
            .fontWeight(index + 1 === this.getCurrentWeekday() ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(index + 1 === this.getCurrentWeekday() ? AppTheme.accent : AppTheme.muted)
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(AppTheme.surface)
    .borderRadius(16)
    .border({ width: 1, color: AppTheme.line })
    .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })
  }

  @Builder
  scheduleCell(weekday: number, period: number) {
    Stack() {
      if (!this.courseCovering(weekday, period)) {
        this.renderCourseAt(weekday, period)
      }
    }
    .width('100%')
    .height(58)
    .backgroundColor(AppTheme.surface)
    .border({ width: 0.5, color: AppTheme.line })
  }

  @Builder
  renderCourseAt(weekday: number, period: number) {
    if (this.courseAt(weekday, period) !== undefined) {
      Column({ space: 3 }) {
        Text(this.courseAt(weekday, period)!.name)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.fg(this.courseAt(weekday, period)!.color))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.courseAt(weekday, period)!.location)
          .fontSize(8)
          .fontColor(AppTheme.muted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(54)
      .padding(6)
      .borderRadius(8)
      .backgroundColor(this.bg(this.courseAt(weekday, period)!.color))
      .border({ width: 1, color: this.fg(this.courseAt(weekday, period)!.color) })
      .onClick(() => this.openEdit(this.courseAt(weekday, period)!))
    }
  }

  @Builder
  scheduleGrid() {
    Column({ space: 1 }) {
      ForEach(this.periods, (period: number, periodIndex: number) => {
        Row() {
          Column() {
            Text(this.periodTimes[periodIndex][0])
              .fontSize(9)
              .fontColor(AppTheme.muted)
            Text(this.periodTimes[periodIndex][1])
              .fontSize(9)
              .fontColor(AppTheme.muted)
              .margin({ top: 2 })
          }
          .width(52)
          .height(58)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.surface)
          .borderRadius(10)
          .border({ width: 1, color: AppTheme.line })

          ForEach(this.weekdays, (day: string, dayIndex: number) => {
            this.scheduleCell(dayIndex + 1, period)
          })
        }
        .width('100%')
      })
    }
    .width('100%')
    .padding({ top: 1, bottom: 1 })
    .borderRadius(18)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.line })
  }

  @Builder
  colorChoice(color: CourseColor, fg: string, bg: string) {
    Row()
      .width(30)
      .height(30)
      .borderRadius(15)
      .backgroundColor(this.formColor === color ? fg : bg)
      .border({ width: 2, color: this.formColor === color ? fg : AppTheme.line })
      .onClick(() => {
        this.formColor = color;
      })
  }

  @Builder
  editorPanel() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(15,23,42,0.28)')
        .onClick(() => {
          this.editorVisible = false;
        })

      Column({ space: 12 }) {
        Row() {
          Text(this.editingId === '' ? '新增课程' : '编辑课程')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink)
            .layoutWeight(1)
          Text('关闭')
            .fontSize(12)
            .fontColor(AppTheme.muted)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(10)
            .backgroundColor(AppTheme.surfaceMuted)
            .onClick(() => this.editorVisible = false)
        }

        TextInput({ placeholder: '课程名称', text: this.formName })
          .height(46)
          .fontSize(12)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(12)
          .border({ width: 1, color: AppTheme.line })
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => this.formName = value)

        TextInput({ placeholder: '上课地点，例如 教学楼A301', text: this.formLocation })
          .height(46)
          .fontSize(12)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(12)
          .border({ width: 1, color: AppTheme.line })
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => this.formLocation = value)

        Row({ space: 8 }) {
          Text('星期').fontSize(12).fontColor(AppTheme.muted).width(42)
          ForEach(this.weekdays, (day: string, index: number) => {
            Text(day.substring(1))
              .fontSize(12)
              .fontColor(this.formWeekday === index + 1 ? Color.White : AppTheme.inkSoft)
              .textAlign(TextAlign.Center)
              .width(31)
              .height(31)
              .borderRadius(16)
              .backgroundColor(this.formWeekday === index + 1 ? AppTheme.accent : AppTheme.surfaceMuted)
              .onClick(() => this.formWeekday = index + 1)
          })
        }

        Row({ space: 8 }) {
          Text('节次').fontSize(12).fontColor(AppTheme.muted).width(42)
          Text('第 ' + this.selectPeriodLabel(this.formStartPeriod) + ' 节起')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.surfaceMuted)
            .borderRadius(10)
            .onClick(() => {
              this.formStartPeriod = this.formStartPeriod >= 8 ? 1 : this.formStartPeriod + 1;
              if (this.formEndPeriod < this.formStartPeriod) this.formEndPeriod = this.formStartPeriod;
            })
          Text('至第 ' + this.selectPeriodLabel(this.formEndPeriod) + ' 节')
            .fontSize(12)
            .fontColor(AppTheme.inkSoft)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.surfaceMuted)
            .borderRadius(10)
            .onClick(() => {
              this.formEndPeriod = this.formEndPeriod >= 8 ? this.formStartPeriod : this.formEndPeriod + 1;
            })
        }

        Row({ space: 8 }) {
          Text('颜色').fontSize(12).fontColor(AppTheme.muted).width(42)
          this.colorChoice(CourseColor.BLUE, AppTheme.accent, AppTheme.accentSoft)
          this.colorChoice(CourseColor.GREEN, AppTheme.success, AppTheme.successSoft)
          this.colorChoice(CourseColor.RED, AppTheme.danger, AppTheme.dangerSoft)
          this.colorChoice(CourseColor.ORANGE, AppTheme.amber, AppTheme.amberSoft)
          this.colorChoice(CourseColor.PURPLE, AppTheme.cyan, AppTheme.cyanSoft)
        }

        Row({ space: 10 }) {
          if (this.editingId !== '') {
            Button('删除')
              .layoutWeight(1)
              .height(46)
              .borderRadius(12)
              .backgroundColor(AppTheme.dangerSoft)
              .fontColor(AppTheme.danger)
              .onClick(() => {
                const id: string = this.editingId;
                this.editorVisible = false;
                this.removeCourse(id);
              })
          }
          Button('保存课程')
            .layoutWeight(2)
            .height(46)
            .borderRadius(12)
            .backgroundColor(AppTheme.accent)
            .fontColor(Color.White)
            .onClick(() => this.saveForm())
        }
      }
      .width('92%')
      .padding(18)
      .borderRadius(22)
      .backgroundColor(AppTheme.surface)
      .shadow({ radius: 18, color: AppTheme.cardShadow, offsetY: 8 })
      .align(Alignment.Bottom)
      .margin({ bottom: 18 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      this.topBar()

      Scroll() {
        Column({ space: 12 }) {
          this.weekHeader()

          Text('点击已有课程可直接编辑；右上角按钮新增课程')
            .fontSize(11)
            .fontColor(AppTheme.muted)
            .width('100%')
            .padding({ left: 4, right: 4 })

          if (!this.loading) {
            this.scheduleGrid()
          }

          Column() {
            Text('我的课程')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ink)
              .width('100%')
              .margin({ bottom: 8 })

            if (this.courses.length === 0) {
              Column({ space: 6 }) {
                Row()
                  .width(26)
                  .height(26)
                  .borderRadius(13)
                  .backgroundColor(AppTheme.cyanSoft)
                Text('暂无课程，点击右上角按钮添加课程')
                  .fontSize(12)
                  .fontColor(AppTheme.muted)
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .padding({ top: 16, bottom: 16 })
            }

            ForEach(this.courses, (course: Course) => {
              Row() {
                Column({ space: 4 }) {
                  Text(course.name)
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.ink)
                  Text(this.weekdays[course.weekday - 1] + ' · 第' + course.startPeriod + '-' + course.endPeriod + '节 · ' + course.location)
                    .fontSize(10)
                    .fontColor(AppTheme.muted)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text('编辑')
                  .fontSize(11)
                  .fontColor(AppTheme.accent)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor(AppTheme.accentSoft)
                  .borderRadius(8)
                  .onClick(() => this.openEdit(course))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 1 }, color: AppTheme.line })
            }, (course: Course) => course.id)
          }
          .width('100%')
          .padding(14)
          .borderRadius(18)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.line })
          .shadow({ radius: 8, color: AppTheme.cardShadow, offsetY: 2 })

          Text('课程信息保存在本机，关闭 App 后仍会保留；后续可替换为校园教务系统同步。')
            .fontSize(10)
            .fontColor(AppTheme.muted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 6, bottom: 22 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      if (this.editorVisible) {
        this.editorPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.canvas)
  }
}
