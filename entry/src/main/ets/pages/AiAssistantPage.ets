import { AiChatService } from '../service/AiChatService';
import { AiAuthService } from '../service/AiAuthService';
import { promptAction } from '@kit.ArkUI';

class ChatMessage {
  text: string
  isUser: boolean

  constructor(text: string, isUser: boolean) {
    this.text = text
    this.isUser = isUser
  }
}

@Component
export struct AiAssistantPage {
  @State inputText: string = ''
  @State showAiLoginDialog: boolean = false
  @State aiEmail: string = ''
  @State aiPassword: string = ''
  @State messages: ChatMessage[] = []
  private scroller: Scroller = new Scroller()

  private selectQuickQuestion(question: string): void {
    this.inputText = question
  }

  build() {
    Column({ space: 16 }) {

      Row() {
        Text('AI 安全助手')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        Button('绑定 AI 账号')
          .fontSize(13)
          .height(36)
          .fontColor('#FFFFFF')
          .backgroundColor('#3478F6')
          .borderRadius(10)
          .onClick(() => {
            this.showAiLoginDialog = true
          })
      }

      .width('100%')

      if (this.showAiLoginDialog) {
        Column({ space: 14 }) {
          Text('绑定 AI 服务账号')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#173B67')

          Text('请输入你在鸿蒙智安 AI 服务中注册的邮箱和密码。')
            .fontSize(13)
            .fontColor('#526174')
            .width('100%')

          TextInput({ placeholder: 'AI 服务邮箱', text: this.aiEmail })
            .type(InputType.Email)
            .onChange((value: string) => {
              this.aiEmail = value
            })
            .width('100%')

          TextInput({ placeholder: 'AI 服务密码', text: this.aiPassword })
            .type(InputType.Password)
            .onChange((value: string) => {
              this.aiPassword = value
            })
            .width('100%')

          Row({ space: 10 }) {
            Button('取消')
              .layoutWeight(1)
              .onClick(() => {
                this.showAiLoginDialog = false
              })

            Button('登录并绑定')
              .layoutWeight(1)
              .onClick(async () => {
                try {
                  await AiAuthService.login(
                    getContext(this),
                    this.aiEmail,
                    this.aiPassword
                  )
                  this.aiPassword = ''
                  this.showAiLoginDialog = false
                  promptAction.showToast({ message: 'AI 账号绑定成功' })
                } catch (error) {
                  console.error('AI account binding failed: ' + JSON.stringify(error))
                  promptAction.showToast({ message: '绑定失败，请检查邮箱、密码或网络' })
                }
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      }

      if (this.messages.length === 0) {

        Column({ space: 14 }) {
          Row({ space: 10 }) {
            Text('🛡️')
              .fontSize(32)

            Column({ space: 4 }) {
              Text('你好，我是智安助手')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#173B67')

              Text('校园安全智能咨询')
                .fontSize(13)
                .fontColor('#3478F6')
            }
            .layoutWeight(1)
          }
          .width('100%')

          Text('无论是消防安全、校园治安，还是突发事件处理，我都可以帮助你了解相关安全知识。')
            .fontSize(14)
            .fontColor('#526174')
            .lineHeight(23)
            .width('100%')

          Row({ space: 8 }) {
            Text('日常聊天')
              .fontSize(12)
              .fontColor('#3478F6')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#EAF2FF')
              .borderRadius(16)
              .onClick(() => {
                this.selectQuickQuestion('你好，陪我聊聊天吧。')
              })

            Text('学习生活')
              .fontSize(12)
              .fontColor('#3478F6')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#EAF2FF')
              .borderRadius(16)
              .onClick(() => {
                this.selectQuickQuestion('请给我一些学习和校园生活方面的建议。')
              })

            Text('校园安全')
              .fontSize(12)
              .fontColor('#3478F6')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#EAF2FF')
              .borderRadius(16)
              .onClick(() => {
                this.selectQuickQuestion('我想咨询校园安全问题。')
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
      }


      Scroll(this.scroller) {
        Column({ space: 16 }) {

          ForEach(this.messages, (item: ChatMessage) => {
            Row() {
              Text(item.text)
                .fontSize(16)
                .lineHeight(24)
                .fontColor(item.isUser ? '#FFFFFF' : '#222222')
                .width('auto')
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(item.isUser ? '#3478F6' : '#FFFFFF')
                .border({
                  width: 1,
                  color: item.isUser ? '#3478F6' : '#E5EAF2'
                })
                .borderRadius(16)
            }
            .width('100%')
            .justifyContent(item.isUser ? FlexAlign.End : FlexAlign.Start)
          }, (item: ChatMessage) => item.text + item.isUser)

        }
        .width('100%')
        .padding({ bottom: 8 })
      }
      .layoutWeight(1)
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: '输入你想咨询的问题', text: this.inputText })
          .onChange((value: string) => {
            this.inputText = value
          })
          .height(44)
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({
            width: 1,
            color: '#E5EAF2'
          })

        Button('发送')
          .onClick(async () => {
            const question = this.inputText.trim()
            if (question.length === 0) {
              return
            }

            this.messages.push(new ChatMessage(question, true))
            this.inputText = ''
            this.scroller.scrollEdge(Edge.Bottom)


            try {
              const context = getContext(this);
              const token = await AiAuthService.getToken(context);

              if (token.length === 0) {
                this.messages.push(new ChatMessage(
                  '请先绑定 AI 服务账号，再使用智能问答。',
                  false
                ));
                return;
              }

              const answer = await AiChatService.sendMessage(question, token);
              this.messages.push(new ChatMessage(answer, false));
            } catch (error) {
              console.error('AI chat request failed: ' + JSON.stringify(error));
              this.messages.push(new ChatMessage(
                '暂时无法回答，请检查 AI 服务账号绑定状态和网络连接后重试。',
                false
              ));
            }


            this.scroller.scrollEdge(Edge.Bottom)
          })
          .width(76)
          .height(44)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor('#3478F6')
          .borderRadius(12)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F7FA')


    }

  }
