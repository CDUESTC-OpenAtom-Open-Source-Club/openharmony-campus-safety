import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { MarkdownBlock, MarkdownParser, MarkdownSpan, MarkdownRow } from '../common/MarkdownParser'

class MarkdownRun {
  spans: MarkdownSpan[] = []
  image: string = ''
  alt: string = ''
}

async function openMarkdownLink(context: common.UIAbilityContext, url: string): Promise<void> {
  const safe = MarkdownParser.safeUrl(url)
  if (safe.length === 0) {
    return
  }
  try {
    await context.startAbility({ action: 'ohos.want.action.viewData', uri: safe })
  } catch (_) {
    promptAction.showToast({ message: '无法打开链接，请稍后重试' })
  }
}

@Component
struct MarkdownImage {
  @Prop source: string = ''
  @Prop description: string = ''
  @State failed: boolean = false

  build() {
    Column({ space: 4 }) {
      if (!this.failed) {
        Image(this.source)
          .width('100%')
          .height(180)
          .objectFit(ImageFit.Contain)
          .accessibilityText(this.description)
          .onError(() => { this.failed = true })
          .onClick(() => {
            openMarkdownLink(getContext(this) as common.UIAbilityContext, this.source)
          })
      }
      if (this.failed || this.description.length > 0) {
        Text(this.failed ? `图片加载失败：${this.description}` : this.description)
          .fontSize(13)
          .fontColor('#526174')
          .copyOption(CopyOptions.LocalDevice)
      }
    }
    .width('100%')
  }
}

@Component
struct MarkdownText {
  @Prop spans: MarkdownSpan[] = []
  @Prop textSize: number = 16
  @Prop strong: boolean = false
  @Prop alignment: TextAlign = TextAlign.Start

  private runs(): MarkdownRun[] {
    const runs: MarkdownRun[] = []
    let current = new MarkdownRun()
    this.spans.forEach((span: MarkdownSpan) => {
      if (span.image) {
        if (current.spans.length > 0) {
          runs.push(current)
          current = new MarkdownRun()
        }
        const image = new MarkdownRun()
        image.image = span.url
        image.alt = span.text
        runs.push(image)
      } else {
        current.spans.push(span)
      }
    })
    if (current.spans.length > 0) { runs.push(current) }
    return runs
  }

  build() {
    Column({ space: 8 }) {
      ForEach(this.runs(), (run: MarkdownRun) => {
        if (run.image.length > 0) {
          MarkdownImage({ source: run.image, description: run.alt })
        } else {
          Text() {
            ForEach(run.spans, (span: MarkdownSpan) => {
              Span(span.text)
                .fontWeight(span.bold || this.strong ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
                .fontFamily(span.code ? 'monospace' : 'sans-serif')
                .fontColor(span.url.length > 0 ? '#245FC5' : (span.code ? '#9A3412' : '#222222'))
                .textBackgroundStyle({ color: span.code ? '#F1F3F7' : Color.Transparent, radius: 3 })
                .decoration({ type: span.strike ? TextDecorationType.LineThrough :
                  (span.url.length > 0 ? TextDecorationType.Underline : TextDecorationType.None) })
                .onClick(() => {
                  if (span.url.length > 0) {
                    openMarkdownLink(getContext(this) as common.UIAbilityContext, span.url)
                  }
                })
            })
          }
          .fontSize(this.textSize)
          .lineHeight(this.textSize * 1.6)
          .width('100%')
          .textAlign(this.alignment)
          .wordBreak(WordBreak.BREAK_WORD)
          .copyOption(CopyOptions.LocalDevice)
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
struct MarkdownCode {
  @Prop code: string = ''
  @Prop language: string = ''

  build() {
    Column({ space: 0 }) {
      Row() {
        Text(this.language || '代码')
          .fontSize(12)
          .fontColor('#526174')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('长按代码复制')
          .fontSize(12)
          .fontColor('#526174')
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#EAF0F8')

      Scroll() {
        Text(this.code.length > 0 ? this.code : ' ')
          .fontFamily('monospace')
          .fontSize(13)
          .lineHeight(21)
          .fontColor('#173B67')
          .copyOption(CopyOptions.LocalDevice)
          .padding(12)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .width('100%')
    }
    .width('100%')
    .backgroundColor('#F3F6FA')
    .borderRadius(8)
    .clip(true)
  }
}

@Component
export struct MarkdownContent {
  @Prop blocks: MarkdownBlock[] = []

  private headingSize(level: number): number {
    const sizes: number[] = [24, 22, 20, 18, 17, 16]
    return sizes[Math.max(0, Math.min(level - 1, sizes.length - 1))]
  }

  private cellAlignment(value: string): TextAlign {
    return value === 'center' ? TextAlign.Center : (value === 'right' ? TextAlign.End : TextAlign.Start)
  }

  @Builder
  table(block: MarkdownBlock) {
    Scroll() {
      Column({ space: 0 }) {
        ForEach(block.rows, (row: MarkdownRow, rowIndex: number) => {
          Row({ space: 0 }) {
            ForEach(row.cells, (cell: MarkdownSpan[], cellIndex: number) => {
              Column() {
                MarkdownText({ spans: cell, textSize: 14, strong: rowIndex === 0,
                  alignment: this.cellAlignment(block.alignments[cellIndex]) })
              }
              .width(156)
              .padding(10)
              .alignSelf(ItemAlign.Stretch)
              .border({ width: 0.5, color: '#CCD6E4' })
            })
          }
          .backgroundColor(rowIndex === 0 ? '#EAF0F8' : (rowIndex % 2 === 0 ? '#F7F9FC' : '#FFFFFF'))
        })
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .width('100%')
    .borderRadius(6)
    .clip(true)
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.blocks, (block: MarkdownBlock) => {
        if (block.kind === 'heading') {
          MarkdownText({ spans: block.spans, textSize: this.headingSize(block.level), strong: true })
            .margin({ top: 6 })
        } else if (block.kind === 'code') {
          MarkdownCode({ code: block.text, language: block.marker })
        } else if (block.kind === 'rule') {
          Divider().color('#D9E1EC').margin({ top: 6, bottom: 6 })
        } else if (block.kind === 'quote') {
          Column() {
            MarkdownContent({ blocks: block.children })
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F3F6FA')
          .border({ width: { left: 1 }, color: '#A8BBD4' })
        } else if (block.kind === 'list') {
          Column({ space: 8 }) {
            ForEach(block.children, (item: MarkdownBlock) => {
              Row({ space: 6 }) {
                if (item.checked >= 0) {
                  Checkbox()
                    .select(item.checked === 1)
                    .enabled(false)
                    .width(16)
                    .height(16)
                    .margin({ top: 5, left: 0, right: 2, bottom: 0 })
                    .accessibilityText(item.checked === 1 ? '已完成' : '未完成')
                } else {
                  Text(item.marker)
                    .fontSize(16)
                    .fontColor('#526174')
                    .lineHeight(26)
                    .constraintSize({ minWidth: 18 })
                }
                MarkdownContent({ blocks: item.children }).layoutWeight(1)
              }
              .alignItems(VerticalAlign.Top)
              .width('100%')
            })
          }
          .width('100%')
        } else if (block.kind === 'table') {
          this.table(block)
        } else {
          MarkdownText({ spans: block.spans })
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
