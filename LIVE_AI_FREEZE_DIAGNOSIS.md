# AI 配置永久加载：现场诊断与修复

日期：2026-10-25。设备：当前连接的鸿蒙模拟器 `127.0.0.1:5555`，OpenHarmony 6.0.0.47 / API20。

## 现场事实

- 原安装版本为 0.2.0，进程 PID 663。账号及数据库初始化约 80 毫秒完成，首页已经加载，故截图中的转圈不是应用启动进度。
- 在原进程调试断点中读取到 `loading=true`、`revision=3`、`privacyReady=false`；没有输出密钥、密码或问答字段。
- 原代码使用同一个 `revision` 管理模型目录失效与安全配置操作。`loadProvider` 捕获旧版本号，`invalidateModels` 增加版本号，而配置读取的 `finally` 只有版本号相等才清除 `loading`。目录状态在读取期间变化，就会让读取结束后仍然锁住表单。
- 新增测试用实际页面控制器重现该交错：配置读取返回 null，`loading` 仍然为 true；修复前 74 项通过、该新增项失败。这个复现不需要假设 Asset 服务挂起。未捕获原页面第一次导致 revision 增加的具体控件回调，因此不把它描述为已逐步追踪到的唯一触发事件。

## 修复

1. 用独立 `configOperation` 标记当前配置读写操作。目录失效仍可拦截旧回复，但不能阻止配置操作释放表单锁；旧配置操作也不能解锁新的配置操作。
2. 配置读取、保存和删除增加 8 秒等待上限。超时会解除等待；迟到的读取不会覆盖用户后续手动输入。
3. 地址、密钥、协议与开关的相同值回调直接返回，避免初始化或受控属性刷新时无意义地失效模型状态。
4. 补充 `ohos.permission.PRIVACY_WINDOW`。现场日志确认系统拒绝原隐私窗口调用，原 manifest 未声明该权限。本机 API20 SDK 也明确列出这个权限；它从 API11 起是 normal / system_grant 权限，见[官方说明](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/security/AccessToken/permissions-for-all.md#ohospermissionprivacy_window)。
5. 修正上一轮 Startup 页传递的存储上下文：重新使用原先的 `getApplicationContext()`，保持账号和数据库目录一致。只恢复读取范围，没有清除、迁移或重建原账号记录。

## 当前模拟器上的实际验证

修复后的 Debug HAP 已通过 hdc 覆盖安装；没有卸载或清除应用数据。模拟器允许此 Debug HAP 安装，不代表未签名 Release HAP 可以用于实体设备分发。

- 原账号登录状态恢复，配置页可打开。
- 配置读取日志在一次实测中从 `21:49:58.641` 到 `21:49:58.730`，约 89 毫秒；后续读取也正常结束。
- UI 自动检查：加载圈数量为 0，“问答”按钮 enabled=true，配置输入控件可用。
- 用页面当前配置实际读取 DeepSeek 模型目录，界面返回“已读取 2 个模型”。没有发送聊天消息或连接测试问答。
- 实际点击“保存安全配置”，界面同时出现“已保存到系统安全存储”和“当前配置已安全保存”，没有加载圈。
- 重新打开 AI 页面后，滚动到状态区域确认“已读取当前账号的安全配置”，加载圈数量为 0，“问答”仍可点。
- 声明权限后，隐私窗口未启用的红字不再出现。这里验证的是页面状态和系统调用不再报错，未进行截图防护的独立攻击验证。
- AI 自动测试现为 78 项通过、0 失败，包括永久锁定、重叠读取、超时迟到回复，以及保存/删除与目录失效的交错。
- 最终 Debug、Release HAP 和 Android Release 构建成功。安卓两个候选 APK 已同步更新；共享代码资源逐项一致，正式包与测试更新包的签名分别验证通过。Android 实机验收和完整 lint 仍未完成。

本次证据保存在已忽略的 `.regression/`：原进程 `live-ai-paused-summary.json`、失败复现 `live-freeze-reproduction.log`、通过测试 `live-freeze-fixed-tests.log`、实测日志 `live-restored-app.log`、模型目录状态 `live-ai-settled-actions.json`、保存结果 `live-ai-save-verification.json`、读回结果 `live-ai-reload-verification.json`。这些记录保留在本机，不上传到远程。

安装包仍放在 `release/v0.2.1/`，已用本轮修复重新构建；以最新 `build-verification.json` 的 SHA-256 为准。实体鸿蒙设备仍需原签名身份签名后的 HAP；当前模拟器已直接运行修复版。
