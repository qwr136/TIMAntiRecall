# TIMAntiRecall

作者 **Xiaofei**；身份 `com.minis.timantirecall`。

为 **TIM 4.1.0 / build 4.1.0.81 / com.tencent.tim / iOS 16.5** 编写的独立 TrollFools 注入动态库。仅交付 `TIMAntiRecall.dylib`，不需要越狱库、PreferenceLoader、deb 或修改版 IPA。

> 0.50 防撤回在用户反馈场景下通过；0.70 的行内红框在用户私聊和群聊均未显示。本轮基于 0.70 补充当前绑定模型发现、传统 AIO 消息转换关联、启动账号补齐和有限 UI 安装重试。已确认代码覆盖缺口，但尚未确认设备失败的唯一根因；此版为针对性复测版，模拟器测试不替代 TIM 真机验证。

## 实现

在 `OCIQQNTWrapperSession` 的 `onMsfPush:msgBuffer:pushExtraInfo:` 入口，先于 C++ 内核处理，仅识别 `trpc.msg.olpush.OlPushService.MsgPush` 中结构完整的撤回通知。

- 私聊：type 528、subtype 138/139，要求有双方 UID 与非零消息序号的撤回载荷。
- 群聊：type 732、subtype 16/17，要求 7 字节前缀、有效长度、非零群号、NotifyType=7、field 11 的非零撤回消息序号列表。
- 其他命令、普通消息、其他群系统通知、未知/重复/截断/超限字段均调用原实现一次，原参数保持不变。
- 不缓存聊天文本或图片、不查询资料服务、不依赖 `TIMAutoRevoke31.dylib`。为逐条匹配，仅在当前进程内保留有限账号/会话/消息序号等键，不写入磁盘。
- 普通 NT 消息行通过 Swift 标准反射读取当前 `viewModel` 和 `record`，撤回到达时有界检查可见行；传统 `QQAIOCell` 通过 `NTRecordConverter` 保存转换前的原消息身份，避免私聊 `clientSeq` 与服务器序号混用。两条链共用精确账号/会话/序号匹配；灰提示排除。标记不抢触摸，复用或解绑时清理。
- 标记最多保留4096条身份，进程结束即消失；重新注入前的撤回不会补标。单包超过64条或身份缺失时只保留原拦截，不猜测标记。细节与证据见 [inline-indicator.md](docs/inline-indicator.md)。
- 按 Bundle ID、版本、构建号、程序名和主程序 UUID 一起限制目标；版本不符时不安装 Hook。
- 主程序头来自公开 `_NSGetMachExecuteHeader()`，要求 MH_EXECUTE/arm64 ALL、64位布局与唯一 LC_UUID；不再用 dyld image0 的 UUID。`image0` 只保留作诊断，不参与身份判断。新日志应出现 `main-execute-header filetype=2`、`main-execute-uuid-valid`，实际 UUID 仍须匹配原目标后才可 `identity-accepted`。

## 安装与停用

1. 在 TrollFools 中仅移除之前启用的本插件旧版（如0.70），结束 TIM 进程；旧 `TIMAutoRevoke31.dylib` 已停用则保持停用，不点“全部启用”。
2. 将 Release 或附件中的 **TIMAntiRecall.dylib** 保存到“文件”。
3. TrollFools → TIM → 注入该动态库，然后完全退出并重开 TIM。
4. 默认启用，没有额外设置面板。移除该动态库并重开 TIM 即停用。

不要覆盖安装 IPA 或卸载 TIM 来换插件，以免丢失本地记录。不同注入器的操作与签名要求须分别核对。

## 验收与限制

先用另一个账号分别在私聊和群聊发送文字、图片；确认 TIM 已收到并显示后撤回，检查原消息是否仍可见。再检查普通收发、群系统消息、主动删除消息、本人撤回，以及退出会话/重开 App 后的状态。

**本轮行内标记尚未真机验收。**请连续发送三条相同文字、只撤回中间一条，确认只有对应行出现红框与“已撤回”；再滚出屏幕并返回、重进会话、切换前后台，检查没有串标且原消息保留。当前只覆盖经该入口到达的实时撤回推送。离线撤回、登录历史同步、云端状态、其他设备和服务端媒体过期可能仍覆盖或删除记录。不能恢复注入前已撤回或从未收到/下载的内容。

当前未区分撤回操作者，因此经相同推送路径返回的本人撤回/本人其他设备撤回也可能被本地保留。发送端和服务端撤回行为不受本库阻止；它不改变其他人的客户端。多个防撤回插件同时存在可能干扰行为。命中目标 UUID 之外的重编译/改版客户端将直接拒绝启用。

## 反馈

本轮优先反馈私聊/群聊是否标对、同文消息是否串标，并附截图；用户已接受日志缺失，不必再反复查旧目录。若已生成新日志，可附 TIM **数据沙盒**（不是 App 安装目录）的 `Documents/TIMAntiRecall/TIMAntiRecall-bootstrap.log`。它在身份校验之前同步记录 constructor-enter、实际 App 版本/构建/UUID、identity-accepted 或 identity-rejected 的原因、Hook 安装与有限收包状态。若 Documents 写入失败或日志超限，后备写入该进程 `TMPDIR`，通常是数据沙盒 `tmp/TIMAntiRecall-bootstrap.log`。每次进程最多 96 条、文件约 128KiB 上限，超限保留旧内容，诊断后可手动备份再清理。

原 `Documents/TIMAntiRecall/TIMAntiRecall.log` 仍只记录通过身份校验后的异步加载/拦截状态。两份日志不记录聊天内容、UID、消息序号或沙盒绝对路径。`constructor-enter` 只说明库的初始化函数执行，`hook-installed` 不等于撤回已拦截；没有任何文件也不能单独证明未加载，目录访问/注入器路径仍需核对。两处文件写入都失败时还会向系统日志发送 `TIMAntiRecall ... file-write=failed` 标记；是否可从设备系统日志读取须实测。

请移除本插件旧版后注入新库，结束并重开 TIM 后做新增消息测试。不需要卸载 TIM 或手动改 App 二进制。若崩溃附对应 `.ips`，标记异常附包含目标行及上下文的截图。

## arm64 对照交付

设备导出的 0.30 是 thin arm64e ABI_V2 (`0x80000002`)，UUID `36B434EF-D990-383D-804D-6DC9D08652E3`；代码、初始化段与原双架构库的 arm64e 片相同。TrollFools 签名工具依设备 CPU 选片，不依目标 App 选择。本轮 Actions 仍编译并校验双架构，但最终精确提取已编译、已签名的 arm64 ALL subtype0，只交付这份薄片；不用修改 CPU header 冒充另一架构。内部 fat、最终 thin、UUID、初始化入口与代码页哈希分别封存。

这不是已证实根因修复：公开 dyld 的 arm64e keys-off 路径允许 arm64 主程序加载 arm64e dylib，所以不能仅由 subtype 不同断言拒载。本轮只减少加载变量，以真机 bootstrap 和消息结果复测。仅针对当前 arm64 TIM，不保证 arm64e-only 主程序或其他 App 兼容。

## 源码 → Actions → 文件

公开仓库只包含本插件的原创源码、测试和构建工具，不上传 TIM IPA、腾讯二进制或旧插件。

`main` 推送自动执行 Linux 源码/真实 C 分类器测试 → macOS Foundation Hook 回归 → 锁定 Theos/Xcode 的真实 arm64+arm64e 编译 → 内部双架构库核验 → 精确提取 arm64 单片并独立核验 → 真实 Swift/UIKit 消息行、复用、前后台模拟器回归 → 带源码 blob、run/attempt 与文件 SHA256 的回执 → Release。

工具链版本来自 `toolchain-lock.json`。SDK 目录标签为 16.5，实际 metadata 是 16.4；最低部署版本为 16.5。CodeDirectory 代码页校验不等于 CMS 信任、注入成功或设备运行验收。
