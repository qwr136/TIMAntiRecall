# Media send repair after 8.70

Baseline `main@222dc53531fe3e82275c20665a04d9d41a2b99d9`; same target TIM4.1.0.81/QQ/iOS16.5/TrollFools. User reports text, mention and quote working in the tested scene, but image/video/sticker replay still failing.

## Proven image bug

8.70 resolves the original cache and recognizes the two taps, then reports a local aggregate failure rather than native submission. Independent inspection of the locked QQ UUID 3C237FA0-5985-3376-BF98-EF1698563247 establishes a deterministic representation mismatch:

- NTAIOContact.convertToOCContact (`0x100222ad0`): ordinary 1/2 branches use nil guildId (`0x100222cec`, argument x4 at `0x100222d18`).
- OCMsgRecord.contact (`0x104cc9a2c` -> `0x104cc9764`) uses Swift String bridging for guildId (`0x104cc97d8`, `0x104cc981c`), producing a nonnil empty string when the underlying value is absent.
- OCContact initializer (`0x10a3b5858`) copies the value without normalization. nil remains nil.
- The old plugin compared these values with isEqual, always rejecting the ordinary nil/empty pair. The synthetic converter erroneously returned an empty string too, hiding the bug from UIKit regression.

The repair only accepts nil/empty NSString as absent for ordinary 1/2 photo contacts. A nonempty guild, whitespace, NSNumber, NSNull or other wrong type is rejected, even if both contacts contain the same nonempty value. chatType and peerUid still require exact equality; source peerUin still must be positive and obtained through the q getter. Other chat types are not normalized.

The supplied log alone does not prove this was the FIRST failed check, so fixed-category photo send diagnostics now separate API, source peer, contact conversion, guild/peer roundtrip, file read/header, temporary copy and native exception. Diagnostics never serialize IDs, paths, bytes, arbitrary errors or message content.

## Regression contract

The native converter fixture now defaults to nil guildId, while record.contact retains its Swift-bridged empty string. The regression explicitly reproduces the old unequal values and runs successful C2C/group sends for all absent representations, then rejects malformed guilds, changed recipient/type, invalid peer number and unsupported chat types. Failure-category and privacy/OFF assertions execute the production path.

The ten recall/wallet production files and established plain text/mention/quote behavior remain unchanged. The former diagnostic freeze explicitly exempts richPhotoContact (intentional fix) and richReplaySend (fixed failure categories); the other eight functions remain frozen, including file open/stat/header logic and element cloning. Source verification alone is not an Apple build or real TIM acceptance.

## Single video native-reference route

The local-file sendShortVideoMsg wrapper creates an asynchronous AVAsset task and does not wire its callback to video completion when no extra text is present. The plugin therefore does NOT use that wrapper, guess a cleanup delay, stage a video copy or delete a borrowed path.

The candidate uses the existing original message ID through the native forwarding route for one ordinary video only:

- `-[QQMsgService getMsgSenderHandlerWithcontact:] @24@0:8@16`, IMP `0x102a778f4`, receives the ordinary NTAIOContact after strict peer/type/no-guild roundtrip.
- Expected returned class `_TtC10MsgManager16MsgSenderHandler`.
- `-forwardMsgWithMsgIds:srcContact:dstContacts:msgAttributeInfos:cb: v56@0:8@16@24@32@40@?48`, IMP `0x104ace374`.
- `ids=@[@(record.msgId)]` preserves q width; source is the current OCContact; destination is a one-element NSArray containing that SAME current contact; attributes are nil. Native Swift wrappers bridge the ID array and OCContact destination array, then forward source unchanged to the kernel. Kernel outline `0x10a15a62c` stores x3 as source, `0x10a15a360` converts it via `0x10a3b5b34`, which consumes chatType/peerUid/guildId. ID converter `0x10a0b45d4` calls `0x10a077824`/longLongValue on each NSNumber.
- Completion is nonnil `void(int32_t, NSString *, NSDictionary *)`; `0x104ace638–64c` calls it with code/message/result. Only a fixed success/error category is logged. No error description, returned-ID map, UID, original ID or resource values are serialized.

The two-tap snapshot retains copied videoMd5/fileUuid and native size/duration plus original message ID/sequence; invalid resources, multiple payloads, wrong type, mixed video/body and unknown metadata shapes fail closed. Existing owner/current-chat/record/deep-equality checks remain in front. Only one native submission occurs; callbacks do not retry. The received OCVideoElement and record are never submitted as mutable payloads. Original video file lifetime and transport stay owned by TIM.

Same-source-and-destination acceptance, remote resource availability, transfer policy, forwarding presentation and actual video delivery remain real-device/server acceptance items. Code 0 is a native callback, not proof the recipient received it. This route is not applied to text, quotes, images or market stickers.

Sticker limitation: photo-backed stickers use the fixed image contact path; the supplied device log does not establish the rejection cause for every market/animated format. Do not claim all sticker formats fixed or change their known sender based on row class alone.
