# 5.80 regression rollback: live messages only

Baseline: 5.20 / `6c33f40b8b9f08c081f339d33f7bccbef465aa98`.

User device feedback for 5.80: new packets no longer claimed in their scenario,
and previously claimed historical packets were automatically attempted again.
This is a failed device result despite the successful 5.80 UIKit/Actions run.

## Production repair

- Restore `TIMAntiRecallInline.m` and `TIMAntiRecallPacket.h` byte-for-byte to 5.20.
  No bind/layout/window callback observes historical records for claiming.
- Remove the loaded-record producer, weak history registry, candidate queue and
  live-promotion logic. A zero `grabbedAmount` is not evidence of unclaimed status.
- Restore the 5.20 original-message-return -> `dispatch_async(main)` boundary,
  original FIFO 32, enqueue attempt check and pre-route 120-second reserve.
- Retain only bounded live-ingress improvements: online, non-imported ordinary
  records aged -4..300 seconds; snapshot 256; pending batch budget 16; 20ms busy
  fallback; queue deadline is receipt time +30 seconds. Pump after a matching
  record within the deferred consumer, without any fixed idle delay.
- Freeze PacketSilent, PacketWallet, PacketOpen, Toast and all other production
  modules/headers to 5.20. No token, wallet eligibility or receipt changes.

## Regression gates

Keep the 5.20 native/UI/background/manual/amount regressions and require:
`packet-fast-main-ingress`, `packet-delayed-live-window`,
`packet-wide-message-batch`, `packet-no-history-auto-attempt`,
`packet-realtime-replay-dedup`.

UIKit must verify no Wallet pre-open before the original receive call returns,
2/4-minute delayed live records after position 64, imported/old/future exclusions,
duplicate live delivery not starting again, and binding/layout of old zero-amount
or already-credited records never starting a native attempt.

## Limits

This disables historical auto-claim rather than claiming a reliable server-side
unclaimed-state detector. The original attempt cache is a short live-delivery
protection, not a persisted ledger of successful claims. No promise of zero
server latency or universal duplicate protection. CI/fixture passing does not
establish real TIM recovery; device acceptance remains pending.
