# TIMAntiRecall

作者 **Xiaofei**；身份 `com.minis.timantirecall`。

为 **TIM 4.1.0 / build 4.1.0.81 / com.tencent.tim / iOS 16.5** 编写的独立 TrollFools 注入动态库。仅交付 `TIMAntiRecall.dylib`，不需要越狱库、PreferenceLoader、deb 或修改版 IPA。

> 当前为待设备验收的测试版本。源码门禁、macOS Foundation 测试、iOS 编译与真机效果是不同验证层；以对应 Actions 和设备反馈为准。

## 实现

在 `OCIQQNTWrapperSession` 的 `onMsfPush:msgBuffer:pushExtraInfo:` 入口，先于 C++ 内核处理，仅识别 `trpc.msg.olpush.OlPushService.MsgPush` 中结构完整的撤回通知。

- 私聊：type 528、subtype 138/139，要求有双方 UID 与非零消息序号的撤回载荷。
- 群聊：type 732、subtype 16/17，要求 7 字节前缀、有效长度、非零群号、NotifyType=7、field 11 的非零撤回消息序号列表。
- 其他命令、普通消息、其他群系统通知、未知/重复/截断/超限字段均调用原实现一次，原参数保持不变。
- 不缓存聊天文本、图片或账号信息，不查询资料服务，不依赖 `TIMAutoRevoke31.dylib`。
- 按 Bundle ID、版本、构建号、程序名和主程序 UUID 一起限制目标；版本不符时不安装 Hook。

## 安装与停用

1. 在 TrollFools 中移除旧防撤回注入，尤其是 `TIMAutoRevoke31.dylib`，结束 TIM 进程。
2. 将 Release 或附件中的 **TIMAntiRecall.dylib** 保存到“文件”。
3. TrollFools → TIM → 注入该动态库，然后完全退出并重开 TIM。
4. 默认启用，没有额外设置面板。移除该动态库并重开 TIM 即停用。

不要覆盖安装 IPA 或卸载 TIM 来换插件，以免丢失本地记录。不同注入器的操作与签名要求须分别核对。

## 验收与限制

先用另一个账号分别在私聊和群聊发送文字、图片；确认 TIM 已收到并显示后撤回，检查原消息是否仍可见。再检查普通收发、群系统消息、主动删除消息、本人撤回，以及退出会话/重开 App 后的状态。

**尚未真机验收。**当前只覆盖经该入口到达的实时撤回推送。离线撤回、登录历史同步、云端状态、其他设备和服务端媒体过期可能仍覆盖或删除记录。不能恢复注入前已撤回或从未收到/下载的内容。

当前未区分撤回操作者，因此经相同推送路径返回的本人撤回/本人其他设备撤回也可能被本地保留。发送端和服务端撤回行为不受本库阻止；它不改变其他人的客户端。多个防撤回插件同时存在可能干扰行为。命中目标 UUID 之外的重编译/改版客户端将直接拒绝启用。

## 反馈

TIM 沙盒 `Documents/TIMAntiRecall/TIMAntiRecall.log` 记录加载、安装状态以及有限次数的私聊/群聊拦截事件，不记录聊天内容、UID 或消息序号。请提供该文件、TIM/iOS 版本、私聊还是群聊、在线还是离线、注入器中旧插件是否已移除；闪退另附对应 `.ips`。

## 源码 → Actions → 文件

公开仓库只包含本插件的原创源码、测试和构建工具，不上传 TIM IPA、腾讯二进制或旧插件。

`main` 推送自动执行 Linux 源码/真实 C 分类器测试 → macOS Foundation Hook 回归 → 锁定 Theos/Xcode 的真实 arm64+arm64e 编译 → dylib 依赖/结构/代码页校验 → 带源码 blob、run/attempt 与文件 SHA256 的回执 → Release。

工具链版本来自 `toolchain-lock.json`。SDK 目录标签为 16.5，实际 metadata 是 16.4；最低部署版本为 16.5。CodeDirectory 代码页校验不等于 CMS 信任、注入成功或设备运行验收。
