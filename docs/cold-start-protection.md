# Cold-start recall protection candidate

Baseline: released 1.00 / `1f5e8da6204732ceef310cdba29993c2ff03e0c8`. User confirms: newly retained text/image is visible for several minutes; force-killing TIM and reopening can replace it with a gray recall row. A six-minute retry once preserved it after earlier five-minute failure/ten-minute success; time alone is not a stable threshold. User explicitly chose to continue without copying message contents/media.

## Narrow protection implemented for evaluation

TIM 4.1.0.81 locked binary UUID `3C237FA0-5985-3376-BF98-EF1698563247`; `-[OCMsgRecord setRecallTime:]` type `v24@0:8q16`, IMP `0x10a1bf32c`. The only direct arm64 call site found for its Objective-C message-send stub is `0x10a1c10f8`, in a complete `OCMsgRecord` field materialization routine. At that point preceding instructions have copied msgId, msgSeq, chatType, senderUid, peerUid, msgTime and other fields before loading `recallTime` from the native input record. This supports exact identity availability at the setter boundary, but by itself does not prove that the startup worker's C++ database writer must traverse this Objective-C conversion.

Startup verifies the exact target executable UUID first, loads persisted identity marks, then installs a method-encoding-checked own setter before the session realtime hook. For positive recall timestamps only, it builds the normal `OCMsgRecord` identity and compares the account/kind/peer-or-group/server-sequence/author key against marks. Exact match returns without changing the timestamp. Every unmatched, malformed, zero/clear value and every ordinary message calls the original typed setter exactly once. It does not hook DeleteMsg APIs or suppress generic deletion.

## Competing hypotheses and unresolved seam

1. Cold recall sync marks or converts the existing `OCMsgRecord` by calling `setRecallTime:`; exact setter protection may prevent the UI's recalled state.
2. The C++ `UpdateMsgToRecallGrayTipByNotify` / `ReplaceToRecallMsg` worker (`0x10a754200`, `0x10a752798`) separately replaces/deletes the database message without relying on the Objective-C setter. The setter hook would then be insufficient.
3. Offline/cached recall path differs based on how long local write/sync settles.

The screenshots establish the user-visible before/after behavior, not which of these internal paths ran. Static C++ call-site analysis shows the special recall update path finds a record and updates/converts it; it does not yet prove a final database commit/rollback boundary. No device trace is available. Do not claim complete cold-start protection unless the real-device 5/6/10-minute repro succeeds, including text and image, after a true process termination.

## Required gates and limits

The branch adds macOS ABI double tests for exact marked private/group identity suppression, mismatched chat/owner pass-through, and zero recall-time forwarding. UIKit test app compiles the actual protection file and invokes it after a true different-PID simulator relaunch before any new push. Existing 1.00 state persistence/source tests remain. CI success only proves the method hook and simulated identity logic; it does not prove that TIM's production C++ sync calls that method or that original content remains visible on device.

No message body, image, audio, video or file is saved. No broad database/UI deletion hook is installed. If the exact setter boundary is not the startup-sync consumer, the requested no-content change may not be achievable safely with current evidence; only then present a separately scoped local content-retention option to the user. Current main/release remains 1.00 until the test change is built and device-checked. Do not modify/promote/push from this branch without completing compile, test, identity and regression checks.
