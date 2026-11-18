# Inline recalled message indicator

0.70 device feedback: neither private nor group rows were decorated. Current binding/legacy compatibility work and its verified static evidence are documented in [inline-binding-fix.md](inline-binding-fix.md); the missing device edge is not yet established.

Baseline: 0.60 / fb7fd59bcc789b7ba013f6c6def2719e957f4e9b. Target remains TIM4.1.0.81, bundle com.tencent.tim, QQ UUID3C237FA0-5985-3376-BF98-EF1698563247, iOS16.5. User's requested UI: thin red rounded border around the whole retained message row including avatar and bubble, fixed lower-right 已撤回 label. Temporary toast is removed.

## Runtime connection

- Existing pre-kernel onMsfPush classifier is byte-for-byte unchanged. Exact source prefix digest is regression checked. Supplemental extraction runs only after a block and never changes forwarding decisions.
- `OCIQQNTWrapperSession -init:depends:dispatcherDepends:listener:` own method v48@0:8@16@24@32@40 obtains owner from its config's typed `OCInitSessionConfig -selfUid` (@16@0:8). Four original parameters are forwarded once. `-close:` v24@0:8@16 clears owner then forwards once. Wrong signature declines tracking, without disabling anti-recall.
- Static binary evidence: init IMP10a195c50 passes config through conversion10a186ae8 (OCInitSessionConfig getWrapperConfig); selfUid10a1867e0; close10a195dc8. `QQAccountsManager +GetInstance` @16@0:8 IMP10010c44c and `-currentUid` @16@0:8 IMP1012502a0 identify currently visible account; sender session owner is never substituted by current account.
- Bounded extractor copies at most64 recall identities: private info fields1/2/20 = from/to/sequence; group Notify1=7,4=group,11→repeated3 with1=seq,2=time,3=random,6=author. Both recognized kinds still block if identity details cannot be safely extracted. Field definitions cross-checked against fixed Lagrange.Core e1bd4baa16fa86ef000154e3eecb7816a29b63a7, not a live TIM capture.
- NT `NTAIOBaseCellView -bindViewModel:` B24@0:8@16 is forwarded once with original BOOL; own unbind/prepare/layout methods are validated. No inherited UIView IMP is overwritten globally. `didMoveToWindow` override is materialized only on target class. Real main-thread calls alone update UI.
- Swift standard Mirror reads the known inherited `NTAIOBaseCellViewModel.record`; no KVC, numeric storage offset or private Swift ABI call. Only normal Message/ChatMessage model ancestry qualifies; GrayTips/RecallNoti reject. Record must be OCMsgRecord. Typed ObjC getters read identities; no message text/media is read.
- Match: owner + chatType(1 private/2 group) + seq + original author + peer/group; optional group time/random must agree. msgId is validated as present but never equated to wire seq. Unknown types fail closed for decoration only.

## Lifecycle and limits

Weak model/view registry, per-bind context, unbind/reuse/leave-window removal, foreground scene revalidation, and return-to-foreground recomputation. Overlay does not change existing frames or capture touch. Marks are held in memory for the current TIM process, bounded to4096 identities (oldest evicted). No disk persistence, no message restoration after process restart. New events for another account are discarded. UI bridge must succeed on actual host; unsupported views/reflective metadata simply produce no mark.

## Evidence required

Linux source/C tests and macOS Foundation identity/session tests are distinct from real UIKit simulator execution. CI builds the real Swift bridge and production UI, launches a UIWindowScene fixture app, observes selected-row marking, no cross-message/account matching, scrolling reuse, weak release and actual background/resume. Screenshots are fixture UI, not TIM. Native/runtime source and UIKit result are sealed to the same SHA/run/attempt before artifact upload.

Actual TIM cell, private/group field semantics and display geometry still require device feedback. Successful simulation demonstrates our implementation under explicit fixtures, not that private host bridges are empirically confirmed. If a row cannot be matched, interception continues without decoration. User's earlier 0.50 functional feedback remains scoped to its tested scenarios.
