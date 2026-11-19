# TIM 4.1.0.81 cold restart and packet trial

This isolated test branch is based on 3.30 (`a2cb2b0`). The constructor still requires the existing TIM bundle/version/build/executable/UUID match. There is one dylib, not a companion plugin.

## Cold restart

1.20 (`f93009f`) checked the accepted wire event at the cold `OCMsgRecord` setter. Later revisions let display bindings veto that lookup or be created by it. The test revision restores the 1.20 wire comparison for cold sync only. Account, conversation, sender, sequence and any original group random/time are still compared; zero/unmatched values still forward exactly once. Cold lookup does not change settings, persisted data or row binding. Private wire events do not carry the materialized record ID. No message contents are cached.

The native test covers materialization with a different local record ID and unchanged wire identity. This addresses a reproducible source-level regression at the setter; it is not evidence that TIM's device database path always crosses that setter. Device acceptance is a received message preserved after the sender recalls it, followed by a true force quit and reopen within one minute, tested independently for private and group chat.

## Packet trial

TIM settings → 防撤回 → 自动领取红包 / 红包诊断日志. Both default off, scoped to the active account, unrelated to the recall setting. `+[_TtC16NTMsgPushMonitor23NTMsgPushMonitorService recvMsgsWithRecords:]` (`v24@0:8@16`) forwards the original array once, then observes a bounded batch while the same account/foreground interval is still current. Local fixtures exercise a Swift-name fallback, two chat types, forwarding, diagnostic-only mode, unsupported and old packets, and duplicate delivery. No chat row is required.

The trial is opt-in and only tries fresh, online, incoming, supported type 2/3 candidates. It delegates to `+[NTRedPackRouterService handleRedPackViewClickWithRootVC:msgRecord:gesture:completion:]` (`v48@0:8@16@24@32@?40`); the locked main image does not consume the gesture. The dynamically resolved Wallet entry and model must pass runtime signature checks first, and a visible native presenter is required. Never calls kernel grab APIs, tampers with credentials, drives a second confirmation, or treats a callback as settled receipt. No automatic retries. The Wallet implementation was not present in the supplied main image. It can present UI or decline; actual receipt and coverage require the real TIM app on device.

Optional `Documents/TIMAntiRecall/TIMAntiRecall-packets.log` contains only fixed event labels and timestamps, not account, content, packet IDs or credentials. Turn on diagnostics to distinguish observation from native route attempt or unavailability. A group and a private packet should be tested from the foreground chat list, using packets sent by a consenting account for testing.
