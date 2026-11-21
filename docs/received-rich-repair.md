# Received-message replay repair after 8.60

Base: `main@5409a3121d7286e431740a7bc2acccac4a1dafeb`. Work continues on main. User explicitly requested repair after supplying a new `replay-rich-reject-v2` session (1795273738.9556201). No wallet/recall changes, no new branch or Release. Target remains TIM 4.1.0.81 / QQ / com.tencent.tim / iOS 16.5 / TrollFools arm64 dylib.

## Device evidence (selected observations, not the complete original log)

- 1795273741.324–3742.260: a real single picture enters rich snapshot, then `photo-path-shape`, field `sourcePath`, valueClass/valueKind `nil`, followed by payload rejection. This proves the implemented sourcePath-only acquisition does not cover this received picture. It does NOT prove the image is undownloaded or that no native cache resource exists.
- 1795273744.710–3745.485: actual `OCVideoElement` is rejected as unsupported. Type 5 is incorrectly labelled face-alt in diagnostics; it is not evidence that the payload is a face.
- 1795273753.934–3754.583: three text elements enter rich snapshot and fail `no-replayable-body`. The log does not expose mention recipient fields; do not claim these three specific entries are definitely @ messages.
- 1795273763.775: a four-element reply reaches `snapshot-ready` and is then rejected because the point is inside the bubble (bubble x108..418, tap x313.33). This is a separate trigger from a bad reference.
- 1795273764.892–3765.519: reply snapshot rejects a typed numeric zero `replayMsgId`. Need native sequence/author-reference evidence, not a guessed replacement ID.
- Emoji row attachment alone does not identify its payload or prove its failing check. Repeated event fingerprints are limited to four and the overall log to 192, so later generic rejections cannot all be assigned one cause.

## Repair invariants

- Established single/plain-text sender stays byte-identical. Multi-text and ordinary targeted mentions use new native OCMsgElement/OCTextElement copies, retaining order and recipient metadata; never flatten @ to display text or retarget it.
- Native role/channel/link/unknown object graphs, malformed metadata and missing mention targets remain rejected.
- Image source acquisition must use verified native contracts; do not guess paths, send displayed thumbnails as originals, or strip flash/invalid flags.
- A zero local replayMsgId must not be replaced with the ID of the enclosing reply; preserve the original reference and all body elements.
- Source checks, real UIKit synthetic-host regression, Actions build, and actual TIM device acceptance remain separate stages.

## Locked native contracts used by this candidate

- Picture: `-[OCPicElement fetchOriginalImgPathWithCreateFolder:] @20@0:8B16`, IMP `0x104be27c4`, dispatches to `0x104be24a0`. The NO branch at `0x104be2704/2754` calls `assembleRichMediaFilePathWithPathInfo:`; the path-info uses photo kind, original-download type, zero thumbnail size, native md5/name/import context. No guessed directory, no create/download request. Only an existing readable sandbox original passes the old stat/open/header checks and existing isolated sender.
- Quote: OC-to-kernel `0x10a1f99a4` and back `0x10a1fa068` preserve zero local IDs. The native quote consumer uses current peer and `replayMsgSeq` without requiring a local ID; sequence is not a substituted message ID or an author-based lookup. This candidate requires an exact positive integral NSNumber when the local ID is zero and leaves the whole reference/body unchanged. Server linking remains device-unverified.
- Mention: `atType` getter `i16@0:8` / setter `v20@0:8i16`. Constants `0x11075dc1c/c20/c24` are 0/1/2. Producer `0x104a2918c` loads user=2; `0x1048d5944` compares all-members=1 and constructs the all-members label. Consumer `0x100f89064` treats 2 as an individual. Text-only fallback accepts 0 or targeted 2; 1, unknown types, guild tiny ID and role/channel/link fields stay rejected. It never turns the visible @ label into plain text. Sending can notify that original target again.

## Remaining limits

Video remains unsupported: its native producer uses an asynchronous AVAsset task and the inspected wrapper does not report video completion through the supplied callback when no additional text is provided. Do not reuse the photo's synchronous temporary-file cleanup. No unfinished video helper or fixture is part of the candidate.

This is not proof that every sticker format is repaired. A sticker represented as a picture can benefit only when the original cache is present; real animated/market rendering and remaining failures require device acceptance. No new remote fetch, message-body logging, wallet or recall change is introduced.

All ten frozen send/build/photo-read/plain-text functions remain byte-identical to 8.40, and all ten recall/wallet files remain byte-identical to 8.10. Only the observed eligibility/cached-original routes and focused regression cases change.
