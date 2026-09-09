import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { Course, CourseColor } from '../model/Course';
import { ScheduleService } from '../service/ScheduleService';

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
      case CourseColor.BLUE: return '#EFF6FF';
      case CourseColor.GREEN: return '#ECFDF5';
      case CourseColor.RED: return '#FEF2F2';
      case CourseColor.ORANGE: return '#FFF7ED';
      case CourseColor.PURPLE: return '#FAF5FF';
      default: return '#F8FAFC';
    }
  }

  private fg(color: CourseColor): string {
    switch (color) {
      case CourseColor.BLUE: return '#2563EB';
      case CourseColor.GREEN: return '#059669';
      case CourseColor.RED: return '#DC2626';
      case CourseColor.ORANGE: return '#D97706';
      case CourseColor.PURPLE: return '#7C3AED';
      default: return '#475569';
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
        .fontSize(30)
        .fontColor('#1F2937')
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.showSchedulePage = false; })

      Text('学生课表')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('本地保存')
        .fontSize(11)
        .fontColor('#94A3B8')
        .margin({ right: 10 })

      Text('＋')
        .fontSize(24)
        .fontColor('#2563EB')
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .onClick(() => this.openAdd())
    }
    .width('100%')
    .height(54)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Color.White)
  }

  @Builder
  weekHeader() {
    Row() {
      Column() {
        Text('本').fontSize(11).fontColor('#9CA3AF')
        Text('周').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#374151').margin({ top: 2, bottom: 2 })
        Text('课表').fontSize(11).fontColor('#9CA3AF')
      }
      .width(48)
      .height(70)
      .justifyContent(FlexAlign.Center)
      .borderRadius(14)
      .backgroundColor('#F5F6F7')

      ForEach(this.weekdays, (day: string, index: number) => {
        Column({ space: 4 }) {
          Text(day).fontSize(12).fontColor('#374151').textAlign(TextAlign.Center).width('100%')
          Text(index + 1 === this.getCurrentWeekday() ? '今天' : '')
            .fontSize(9)
            .fontWeight(index + 1 === this.getCurrentWeekday() ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(index + 1 === this.getCurrentWeekday() ? '#2563EB' : '#9CA3AF')
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(Color.White)
    .borderRadius(16)
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
    .backgroundColor(Color.White)
    .border({ width: 0.5, color: '#F0F2F5' })
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
          .fontColor('#64748B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(54)
      .padding(6)
      .borderRadius(8)
      .backgroundColor(this.bg(this.courseAt(weekday, period)!.color))
      .border({ width: 0, color: '#2563EB' })
      .onClick(() => this.openEdit(this.courseAt(weekday, period)!))
    }
  }

  @Builder
  scheduleGrid() {
    Column({ space: 1 }) {
      ForEach(this.periods, (period: number, periodIndex: number) => {
        Row() {
          Column() {
            Text(this.periodTimes[periodIndex][0]).fontSize(9).fontColor('#6B7280')
            Text(this.periodTimes[periodIndex][1]).fontSize(9).fontColor('#9CA3AF').margin({ top: 2 })
          }
          .width(52)
          .height(58)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(Color.White)
          .borderRadius(10)

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
    .backgroundColor('#FFFFFF')
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
            .fontColor('#111827')
            .layoutWeight(1)
          Text('×')
            .fontSize(24)
            .fontColor('#64748B')
            .onClick(() => this.editorVisible = false)
        }

        TextInput({ placeholder: '课程名称', text: this.formName })
          .height(46)
          .backgroundColor('#F8FAFC')
          .borderRadius(12)
          .onChange((value: string) => this.formName = value)

        TextInput({ placeholder: '上课地点，例如 教学楼A301', text: this.formLocation })
          .height(46)
          .backgroundColor('#F8FAFC')
          .borderRadius(12)
          .onChange((value: string) => this.formLocation = value)

        Row({ space: 8 }) {
          Text('星期').fontSize(12).fontColor('#64748B').width(42)
          ForEach(this.weekdays, (day: string, index: number) => {
            Text(day.substring(1))
              .fontSize(12)
              .fontColor(this.formWeekday === index + 1 ? Color.White : '#475569')
              .textAlign(TextAlign.Center)
              .width(31)
              .height(31)
              .borderRadius(16)
              .backgroundColor(this.formWeekday === index + 1 ? '#2563EB' : '#F1F5F9')
              .onClick(() => this.formWeekday = index + 1)
          })
        }

        Row({ space: 8 }) {
          Text('节次').fontSize(12).fontColor('#64748B').width(42)
          Text('第 ' + this.selectPeriodLabel(this.formStartPeriod) + ' 节起')
            .fontSize(12)
            .fontColor('#334155')
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor('#F8FAFC')
            .borderRadius(10)
            .onClick(() => {
              this.formStartPeriod = this.formStartPeriod >= 8 ? 1 : this.formStartPeriod + 1;
              if (this.formEndPeriod < this.formStartPeriod) this.formEndPeriod = this.formStartPeriod;
            })
          Text('至第 ' + this.selectPeriodLabel(this.formEndPeriod) + ' 节')
            .fontSize(12)
            .fontColor('#334155')
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor('#F8FAFC')
            .borderRadius(10)
            .onClick(() => {
              this.formEndPeriod = this.formEndPeriod >= 8 ? this.formStartPeriod : this.formEndPeriod + 1;
            })
        }

        Row({ space: 8 }) {
          Text('颜色').fontSize(12).fontColor('#64748B').width(42)
          this.colorChoice(CourseColor.BLUE, '#2563EB', '#EFF6FF')
          this.colorChoice(CourseColor.GREEN, '#059669', '#ECFDF5')
          this.colorChoice(CourseColor.RED, '#DC2626', '#FEF2F2')
          this.colorChoice(CourseColor.ORANGE, '#D97706', '#FFF7ED')
          this.colorChoice(CourseColor.PURPLE, '#7C3AED', '#FAF5FF')
        }

        Row({ space: 10 }) {
          if (this.editingId !== '') {
            Button('删除')
              .layoutWeight(1)
              .height(46)
              .borderRadius(12)
              .backgroundColor('#FEF2F2')
              .fontColor('#DC2626')
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
            .backgroundColor('#2563EB')
            .fontColor(Color.White)
            .onClick(() => this.saveForm())
        }
      }
      .width('92%')
      .padding(18)
      .borderRadius(22)
      .backgroundColor(Color.White)
      .shadow({ radius: 18, color: 'rgba(15,23,42,0.18)', offsetY: 8 })
      .align(Alignment.Bottom)
      .margin({ bottom: 18 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  colorChoice(value: CourseColor, textColor: string, bgColor: string) {
    Text('●')
      .fontSize(16)
      .fontColor(textColor)
      .textAlign(TextAlign.Center)
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor(bgColor)
      .border({ width: this.formColor === value ? 2 : 0, color: textColor })
      .onClick(() => this.formColor = value)
  }

  build() {
    Stack() {
      Column() {
        this.topBar()

        Scroll() {
          Column({ space: 12 }) {
            this.weekHeader()

            Text('点击已有课程可直接编辑；右上角「＋」新增课程')
              .fontSize(11)
              .fontColor('#94A3B8')
              .width('100%')
              .padding({ left: 4, right: 4 })

            if (!this.loading) {
              this.scheduleGrid()
            }

            Column() {
              Text('我的课程')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')
                .width('100%')
                .margin({ bottom: 8 })

              if (this.courses.length === 0) {
                Text('暂无课程，点击右上角「＋」添加课程')
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 16, bottom: 16 })
              }

              ForEach(this.courses, (course: Course) => {
                Row() {
                  Column() {
                    Text(course.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#334155')
                    Text(this.weekdays[course.weekday - 1] + ' · 第' + course.startPeriod + '-' + course.endPeriod + '节 · ' + course.location)
                      .fontSize(10)
                      .fontColor('#94A3B8')
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)

                  Text('编辑')
                    .fontSize(11)
                    .fontColor('#2563EB')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor('#EFF6FF')
                    .borderRadius(8)
                    .onClick(() => this.openEdit(course))
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .border({ width: 0, color: '#E5E7EB' })
              }, (course: Course) => course.id)
            }
            .width('100%')
            .padding(14)
            .borderRadius(18)
            .backgroundColor(Color.White)

            Text('课程信息保存在本机，关闭 App 后仍会保留；后续可替换为校园教务系统同步。')
              .fontSize(10)
              .fontColor('#B0B7C3')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 6, bottom: 22 })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 20 })
        }
        .layoutWeight(1)
        .backgroundColor('#F5F6F7')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F6F7')

      if (this.editorVisible) {
        this.editorPanel()
      }
    }
    .width('100%')
    .height('100%')
  }
}
