# Current binding and legacy row compatibility

Baseline 0.70 / bcd260bb291016edc2d45c3ae218a6df6e0d4498. User reports retained messages without any red border/已撤回 in both private and group chats. Actual device renderer and missing correlation edge remain unknown. This is a targeted compatibility change, not a claim that the device cause has been proven.

## Verified static gaps

- NT Swift binding has vtable calls at 0x1049e991c and native binding body0x1049e97d0, distinct from the Objective-C thunk0x1049e9be4. The existence of a thunk does not guarantee Swift callers go through its IMP. The stored NTAIOBaseCellView.viewModel field is present in Swift reflection metadata (descriptor0x10b603a10, field typeref0x10b568e48). Now UIKit layout/window callbacks and one bounded visible-view walk per accepted recall batch read the current optional model with standard Mirror. No raw offsets or private Swift runtime functions.
- TIM includes traditional QQAIOCell with setAioModel: v24@0:8@16 IMP10053727c, updateCellView v16 IMP100538360, prepareForReuse IMP1005384d8 and layoutSubviews IMP100538594. These own methods are signature-checked, original-forwarded exactly once, with an inherited didMoveToWindow override materialized only on that target class.
- NTRecordConverter +recordConvertMessageModel: @24@0:8@16 IMP100224040 returns QQMessageModel. +recordConvertAIOMsgModel: IMP100224734 creates QQAIOMsgModel and calls recordConvertMessageModel: (branch107c0b710 -> selector stub10b1d69c0), then setMsgModel: (107c0ce80 ->10b3349e0).
- Conversion first reads OCMsgRecord.msgSeq at10022413c, but chatType1 overwrites old msgSeq with clientSeq at1002241b8–1002241c4; chatType2 preserves server sequence. Therefore wire seq must not be blindly compared with traditional QQMessageModel.msgSeq. New conversion hook preserves only the immutable original identity dictionary, never the record/message body. The resulting object's seq(q), msgID(i), msgUid(q), peerUin(@) and groupCode(@) fingerprint guards mutation. QQAIOMsgModel.msgModel must still be the associated result. No association means no decoration.
- 0.70 captured currentUid during binding once. If absent during login, the context could never match a later valid owner. Missing owner now resolves once; a nonempty owner is never relabeled during account changes.
- TIM Info.plist has no UIApplicationSceneManifest. A window with no UIWindowScene uses UIApplicationStateActive explicitly; scene windows use their actual activation state.

## Implementation and tests

Wire/classifier, interception/forwarding, session config selfUid capture and matching keys remain unchanged. UI install retries at most10 times and on recall; each rendering route independently activates when validated. Visible tree walking is main-thread, max2048 views and depth24, no message text searches, no recurring timer. Unknown/malformed identities remain undecorated.

Real UIKit fixtures now store optional viewModel in Swift and include direct-storage writes which bypass bindViewModel:, nil/replacement/return cases, initial missing account, traditional private/group conversion with different client/server sequences, mutation/account/notice/unlinked-model negatives, off-window/return/reuse, and actual onMsfPush -> Session -> Wire -> store -> current row -> indicator. Fixture classes are explicit test doubles; no proprietary executable is shipped or run in the simulator. Existing geometry/touch/weak-release/background tests remain required.

Remaining device uncertainty: actual renderer route, real per-message field semantics, session-wrapper owner availability and timing, proprietary Swift reflection output, older pre-conversion cached models and final composite pixels. If unmatched, anti-recall continues without decoration. No claim to restore history marks or persist them across process restart. Bounded discovery can add main-thread work during recall bursts; device performance is unmeasured.
