# Hook evidence and verification scope

Input: TIM 4.1.0, CFBundleVersion 4.1.0.81, com.tencent.tim, executable QQ.

IPA SHA256: `6738a20c90ba1cd43e15cf5f7aa3a08b117db666d9e06bd07b3d7638acd47fab`.

Main UUID: `3C237FA0-5985-3376-BF98-EF1698563247`; real slice ARM64/CPU subtype 0; cryptid=0. No Tencent binary or old plugin is included in this repository.

## Typed boundary

`-[OCIQQNTWrapperSession onMsfPush:msgBuffer:pushExtraInfo:]`

Encoding `v40@0:8@16@24@32`; IMP at unslid VM address `0x10a196488`, method-list entry `0x10dc812d8` in the supplied binary.

Prototype: `void (id self, SEL _cmd, id command, id messageBuffer, id pushExtraInfo)`.

The implementation converts command and message buffer to C++ representations, then invokes the session virtual method at vtable+0x90 (`0x10a1964e0` through `0x10a1964f8`). The buffer conversion helper at `0x108b26140` gets the buffer bytes/length and constructs a C++ byte vector. This is before the kernel consumes the push, unlike an `onMsgRecall` listener.

The hook requires the runtime method to be an own instance method with void return, exactly five arguments and exact object/selector encodings. Unknown signatures and inherited methods are rejected. It stores the original IMP with atomic publication, never strips/signs PAC pointers manually, and forwards untouched inputs once for non-matching packets.

## Native recall dispatcher

The supplied binary's C++ dispatcher at `0x10a753664` tests:

- `0x10a753684`: type 0x210; `0x10a753680` masks subtype's lowest bit, then `0x10a75368c` compares 0x8a → subtypes 138/139. Calls recall worker `0x10a75ed88` at `0x10a7536d4`.
- `0x10a75370c` through `0x10a753714`: type 0x2dc and masked subtype 0x10 → subtypes 16/17. Calls group worker `0x10a760378` at `0x10a7538ac`.
- Other subtypes 0x141/0x15 route to separate nudge handling and are not classified as message recall.

The group worker confirms message body/bytes content, requires more than 7 bytes, skips 7 (`0x10a7604d8`) and parses NotifyMsgBody. It requires a nonzero field 4 group code (`0x10a760518`–`0x10a760520`), reads field 1 and requires 7 (`0x10a760554`–`0x10a760564`), then requires field 11 (`0x10a76056c`–`0x10a76057c`). It logs a missing `opt_msg_recall` for invalid input. This is why broad blocking of all type-732 system messages is inappropriate.

`trpc.msg.olpush.OlPushService.MsgPush` is referenced by the kernel's `onMsfPush` consumer at `0x109fe4f80` (reference `0x109fe4fdc`).

## Wire-field corroboration

Envelope field numbers are cross-checked with public protocol definitions at LagrangeDev/Lagrange.Core commit `e1bd4baa16fa86ef000154e3eecb7816a29b63a7`:

- `Internal/Packets/Message/NTPushService.cs`: MsgPush field 1 = CommonMessage.
- `Internal/Packets/Message/NTMessageCommon.cs`: CommonMessage field 2 = ContentHead, field 3 = MessageBody; ContentHead fields 1/2 = type/subtype; MessageBody field 2 = msg content.
- `Internal/Packets/Notify/FriendRecall.cs`: field 1 info, fields 1/2 UIDs and 20 sequence.
- `Internal/Packets/Notify/NotifyMessageBody.cs` and `GroupRecall.cs`: fields 1/11 and recall message list field 3 with sequence field 1.
- `Internal/Logic/Processors/FriendRecallMessageProcessor.cs` and `GroupRecallMessageProcessor.cs`: independently agree with the supplied binary's observed dispatch constants and 7-byte group-content framing.

These external field definitions corroborate static analysis; they are not a runtime capture from the user's TIM. This gap is explicit. The parser conservatively forwards unknown, malformed, duplicate, unsupported-wire-type, oversized or ambiguous messages. It has no recursive parsing or unbounded allocation.

## Pending device checks

The static chain establishes a plausible pre-consumer interception boundary. It does not prove that the user's online/offline sessions always reach this boundary, nor that ignored push messages won't be delivered again or superseded during history synchronization. Real TIM/iOS16.5 injection and separate private/group recall tests are mandatory before claiming functional acceptance. Local active deletion is not hooked; own recall push is currently not distinguished and may also remain locally visible.
