# Bubble-outside double-tap replay (TIM 4.1.0.81)

Baseline: plugin 6.40 / `5963c5b02facef602e777377b9f2ca8a876e0199`. The plugin version is not the TIM host version.

## Changes
- Stop replacing TIM's content double-tap service. Tapping text still runs TIM's own reader/copy/highlight/translation interaction.
- On ordinary NT message rows, reuse the existing bind/layout/current-model bridge and install one owned UIKit double-tap recognizer on the one-to-one table/collection cell content host. No coordinate tap injection and no extra buttons/windows.
- Resolve stored `NTAIOCellView.content/avatar/title/status/checkView/tailContainerView` with bounded Swift reflection, not guessed getters/offsets. Accept the full available whitespace on the correct side of the bubble, from a 6 pt inset to the message-row host edge, spanning only that row's height. Reject bubble, avatar, labels, controls, auxiliary views, invalid geometry and ambiguous row hosts.
- Use two touch samples on the same current model/identity/controller/account, unchanged bubble and scroll offset. Invalidate on reuse, rebind, account/scene/settings transitions. Require the native scroll pan to fail; do not replace existing gesture delegates or change their failure dependencies.
- The old QQ chat-controller type restriction blocked modern NT controllers. Resolve the actual responder controller's inherited `NTAIOChatBaseViewController.chatContext`, then compare its chatType/peerUid with `OCMsgRecord.contact` before submitting.
- Native sender: `QQMsgService +getInstance`, `-sendTextMsgByOCContact:richText:callBack:` (`v40@0:8@16@24@?32`). Static disassembly confirms richText is NSString and nil user callback is guarded. Invoke once, with the original contact and text; do not touch input-bar drafts, forge receipts, retry, or call multiple send paths.
- Do NOT use AIOLib `sendInputText:`: inspected base code inserts a local table model; this is not proof of native message submission.

## Scope and limits
Existing `messageReplay` preference is retained, default OFF for fresh settings. An existing ON value stays ON. Plain text retains its native parsing path. From the 8.10 baseline, [rich-message-replay.md](rich-message-replay.md) adds cloned face/market-face/whole-quoted-reply elements and local single-image native upload. Unsupported formats fail closed rather than losing payloads. Native service invocation is not delivery confirmation.

Packet ingress, wallet/open/silent/amount/toast modules are unchanged. Unknown/legacy chat controllers or unavailable fields/ABI skip replay. A row with no unobstructed side whitespace remains untappable; no overlay, label or button is injected into the target row.

## Verification
Source contracts and synthetic UIKit fixtures must cover modern NT inheritance, unchanged native text double tap, original contact/text, untouched draft, incoming/own/group cases, single tap, controls, mentions/mixed content, scroll/rebind/reuse/account/scene/chat-switch negatives and gesture cleanup. Existing packet/recall/settings tests remain mandatory.

Synthetic UIKit uses real views/recognizer configuration and the shared delegate/action decision code, but is not the real TIM host and does not inject physical touches. Native send ABI/contracts are checked against the local decrypted TIM 4.1.0.81 binary; actual on-device geometry, gesture competition, injection, server eligibility and delivery remain device acceptance items. CI success must never be reported as real TIM acceptance.
