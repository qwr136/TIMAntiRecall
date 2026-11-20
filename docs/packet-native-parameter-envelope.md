# 4.90 native entry envelope regression

Baseline: `fd3e102ed930690faa36da4255093902bbd3967e` (4.90, user-reported device failure). Known-good device rollback remains 4.60 / `c41642dfa1ce88797297c86afe773cfbbf576720`.

The user's 2026-11-20 03:14:31–39 UTC device log has `redpack-private-observed → queue2-enqueued → queue2-waiting-state → redpack-background-native-route → queue2-started → redpack-silent-native-error`. This proves the ingress and queue reached a native background route. It does not by itself identify the error's origin, prove a request reached the network, or establish that no off-window native path exists. In 4.90 a plugin-generated entry rejection and an actual native error share the same final phase.

## Confirmed independent source defect

The native Wallet receives the outer dictionary created by `QQWalletNTRedPackMsgModel -grabHBParam`. In the exact decoded Wallet image UUID `E1D271FD-4914-3FD9-9F85-2C281F8B8147`:

- `0x5788b0–0x5788bc` allocates the inner dictionary in x21. `0x5788c4` reads original `billNo`; CFString `0xc1d348` is `listid`; helper `0x526ee8` performs `[x21 setObject:x23 forKey:x3]` at `0x5788dc`.
- `0x578abc–0x578acc` creates the outer dictionary in x23. `0x578b7c–0x578b84` copies the inner x21 into x24. CFString `0xc16568` is `extra_data`; helper `0x500834` performs `[x23 setObject:x24 forKey:x3]` at `0x578b90`.
- The native method returns a copy of x23 at `0x578cc4–0x578ccc` / `0x578cf8`.
- `QQWallet -gotoTenpayView:rootVC:params:completion:` retains the original params object into x21 at `0x477900–0x477904`; the normal `graphb` branch forwards that same object as x3 to `grabHB:params:completion:` at `0x4779a8–0x4779b0`.
- The independent native reader `QQWalletGrapHBAIOData +createHBAIODataWithParam:` extracts outer `extra_data` at `0x578f4c–0x578f64`; x21 is that inner dictionary. It reads its `listid` and applies `setListId:` at `0x5791fc–0x579228`. Native `parseHBChannel:` likewise reads `extra_data` at `0x4ed868–0x4ed880`.

4.90 incorrectly tested `params[@"listid"]` rather than `params[@"extra_data"][@"listid"]`. Under the native format above, this is necessarily nil, so the plugin rejects before it forwards original `grabHB:` and before any popup/pre-open can run. The synthetic fixture also used the wrong flat format and therefore passed despite the bug. This explains a concrete failure path consistent with the user's log; it does not prove the device has no additional downstream issue once corrected.

## Minimal correction

- Only change `PacketSilent`'s entry identity lookup to the native nested dictionary. Reject invalid envelope, non-string bill, mismatched bill, invalid authorization, unresolved ABI or a non-supported native route as before. Do not accept an outer bill fallback.
- Preserve the original envelope object and root/completion identity when forwarding, exactly once. Native qualification predicates still receive the full original envelope. No token, request parameter, business result or qualification is changed.
- Record only fixed rejection reasons and a forwarded-entry phase. Preserve the specific local reason through the asynchronous final callback. Native wallet errors keep a separate generic phase plus a numeric error code; do not log error domains/descriptions/userInfo, params, IDs, amounts or tokens.
- Change the UI doubles to the actual nested outer/inner format. The existing foreground/background/private/group/manual/late-receipt series then tests the formerly missing contract. New direct guard cases additionally require nested success, exact forwarded-object identity, flat/malformed/missing/numeric/mismatched rejection, native legacy/no-pre-open rejection and distinct native errors. All previous lifecycle, FIFO, native-slot, no-popup and amount-timer coverage stays enabled.

## Acceptance

Source tests are structural only. Actual UIKit tests still use synthetic native-facing objects, not the proprietary TIM host or a real server. Actions success is not device acceptance. Device acceptance must confirm the new forwarded phase, popup-suppressed phase and same-bill receipt, with no red/grey popup; then test consecutive and naturally executing background arrivals. Stable 4.60 remains available; do not merge this candidate into the stable branch or publish a formal Release before device feedback.
