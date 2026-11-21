# Rich message replay on main (8.10 baseline fd36b45)

## Contract and implementation

The user's requirement is one immediate replay of the whole clicked reply, including its existing quote relationship, not a new reply quoting that reply and not just sending the quoted text. Supported native element families are text (1), face (3/5), market-face (11) and quote/reply (7). A message containing a quote must include a body; nested quote previews (text/face/picture descriptors) are rebuilt recursively. One quote descriptor is allowed. Standalone unsupported mentions/links still use the unchanged plain-text eligibility policy. Interactive random/poke faces are excluded.

Received message objects are never passed to a rich sender. A fixed property allowlist, generated from the locked QQ 4.1.0.81 Objective-C ivar/getter/setter metadata, verifies each actual method encoding. A bounded description copies NSString/NSNumber/NSData and numeric/string arrays into an immutable snapshot. Native OCMsgElement and payload objects are allocated anew; elementId resets to zero, and the native sender generates the new message ID. All quote IDs, sender fields (including NSNumber senderUid), root/client sequence, text/preview descriptors and supported metadata are preserved. Unknown nested object graphs are rejected, not silently omitted. Received msgAttrs/UI extension/server delivery metadata are not reused. Snapshots exist only in memory until gesture completion/cancellation.

The same row, account, current conversation, controller, geometry, scroll offset and full content snapshot must match across both touches and final submission. Rebind, scroll, account/scene changes and disabling the feature cancel the pending gesture. Existing outside whitespace and native text double tap remain unchanged.

## Verified native interfaces

- QQMsgService +getInstance; -sendMsgWithOCContact:msgElems:msgAttributeInfos:callBack: `v48@0:8@16@24@32@?40`, IMP 0x102a77d5c. Uses record.contact after comparison with current NT chat context. Fresh elements, nil outgoing attrs (native supported optional), nonnull completion `void(int32_t, NSString *)` (descriptor v20@?0i8@"NSString"12). Callback only records a fixed result token, never retries or alters the editor.
- -sendPicMsg:sourcePath:additionalMsg:picSubType:callBack: `v52@0:8@16@24@32i40@?44`, IMP 0x102a773c0. First argument is NTAIOContact (not OCContact). Exact q chatType and peerUin mapping is roundtrip-validated through convertToOCContact (0x100222ad0), comparing OCContact chatType/peerUid/guildId without normalizing nil to empty.
- Native local photo closure 0x102a775f8 synchronously loads UIImage/NSData, creates NTPhotoResult (0x104ad4f98) and calls MsgSenderHandler.sendPicMsgWithPhotoResult:fileType:thumbSize:sendMsgResultBlock: (0x104ad535c). additionalMsg is nil, so no second text message is requested. Source bytes are copied to a UUID-named 0600 temporary file; only the copy enters the native producer. It is removed after the synchronous native read and again harmlessly on completion. Original file is untouched.

## Photo limits and effects

Only a single image with a complete readable sandbox-local sourcePath (max 24 MiB) is accepted. Flash/invalid images are refused. Canonical sandbox containment, regular file, inode/device/size/mtime and O_NOFOLLOW are checked; file identity must remain unchanged between touches and while reading. JPEG/PNG/GIF/WebP/HEIF signatures are recognized; actual supported formats/animation/original quality remain determined by TIM's native producer, not a plugin promise. No guessed remote downloads, received fileUuid reuse or thumbnail fallback. Photos mixed with reply/body require a different native upload composition and are not implemented by this candidate.

Large-image I/O runs on main during the actual confirmed double tap (not during every layout); the 24 MiB limit bounds it, but there can be a brief stall. Temporary copies are not persistent chat backups. A process kill in the short copy/native-read window can leave a file in the app's system-managed temporary directory.

## Regression and evidence boundaries

New real UIKit fixtures cover face/market metadata, whole quote + reply body, nested quote object isolation, incoming/own/group routes, original objects remaining unchanged even if the sender mutates its fresh inputs, two-tap payload/quote/file replacement rejection, switch/account/chat/scroll/reuse cancellation, local PNG native handoff, contact roundtrip, missing/remote/flash/invalid photos, retained original bytes and temp cleanup. Source contracts pin exact metadata and 10 frozen recall/wallet production files to 8.10. CI requires all five rich replay coverage labels. These are synthetic TIM models with real UIKit, not real TIM delivery. Server acceptance, native media upload, animated sticker rendering and live quote linking require device acceptance.

No recall/wallet implementation is changed. Work stays on main; ordinary builds upload verified artifacts without creating Release/tag.
