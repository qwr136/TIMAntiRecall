# Foreground claim amount toast

Baseline: user-accepted 4.40 / `4db9f12879f01f789e87a875076603647e94643a`.
The user confirmed automatic and consecutive claims on 2026-11-20. This feature only adds a centered, noninteractive receipt label; all earlier device acceptance remains limited to the user's tested environment.

## Change

- Only the existing authorized, same-bill native successful dismissal can supply the toast. Keep its original dismissal, completion notification and callback-slot handling unchanged.
- Read the current recipient's `grapResultData.recv_object.amount`, never the total sent amount or an earlier message-model amount. Positive integer fen become exact two-decimal yuan; unknown or malformed amounts produce no label and do not change the native finish behavior.
- Display `已领取 ¥1.23` in the center of the originating foreground window for 3 seconds. Do not create a window, take focus, intercept taps, store amounts, or log them.
- A later successful receipt replaces the visible value and restarts its UI-only three-second timer. It neither waits for the old toast nor blocks the next packet. Old timers cannot clear newer values.
- Clear immediately on app deactivation/backgrounding or deactivation/disconnection of the originating scene. Unrelated scenes do not clear it.
- Manual claims, errors and unknown results do not create or refresh this automatic-claim toast. Existing automatic/self-sent settings are unchanged; no extra setting is added.

## Amount unit evidence

Read-only local decrypted `QQStartupOnLogin`, UUID `E1D271FD-4914-3FD9-9F85-2C281F8B8147`:

- `QQWalletGrapHBData -receiveHBInfo` (`0x5740d8`) gets `grapResultData` and dictionary key `recv_object` (CFString `0xc2ca08`).
- `QQWalletGrapHBResultView -showHBMoney` (`0x540b2c`) reads `receiveHBInfo.amount` (CFString `0xc2aa48`), calls `doubleValue` at `0x540b84`, preserves it in d8, and passes it to `moneyAndTipsView:moneyFontSize:` at `0x540d10`.
- The helper preserves the first double argument and passes it to `moneyAttributedString:moneyFontSize:`. That method divides by the double constant 100 (`0x4059000000000000`, `0x485464–0x48546c`) and formats `%.2f` (CFString `0xc1eb88`). The toast follows the same unit conversion using integer arithmetic to avoid floating-point rounding.

## Verification

The claim queue, auto-open, authorization, shared callback-slot checks, preferences, recall protection and no-detail matching conditions are frozen to 4.40. Source checks plus the actual production UIKit component test native success/received-not-sent amount, no unconfirmed/manual refresh, malformed values, center geometry, hit-test passthrough, 3-second expiry, replacement timer isolation and lifecycle cleanup. CI also retains all previous continuous-claim assertions and requires UIKit plus compositor screenshots. These fixtures are not the real TIM app; device amount accuracy and appearance remain to be verified by the user after installing the new build.
