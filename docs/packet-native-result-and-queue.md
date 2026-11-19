# Native Wallet response / serial queue candidate (from 4.00)

Baseline: `337395a6648948d16bdac5e4ae5a20d9e27111ff`, TIM `4.1.0.81`, main UUID `3C237FA0-5985-3376-BF98-EF1698563247`. Existing recall, display, cold-restart, settings and retired log sinks are frozen.

## Device evidence and diagnosis

The user reports successful auto-open but no return on the native detail page, no claims after switching apps/locking, and second packets sometimes skipped. Device trace `open1` at UTC 17:54:09 forwards the WeakProxy `openButtonClick` on `QQWalletPreOpenHBView` in `QQStartupOnLogin`; a normal callback follows but UTC17:54:17 logs `close-skipped-receipt-unconfirmed`. This proves the *old confirmation predicate* stayed false, not which conjunct caused it. Screenshot shows a detail page reporting a 0.01 claim; screenshot and trace are separate reproductions, not proof of the same packet.

New user-supplied IPA has decrypted main and Wallet module (`cryptid=0`). Wallet UUID `E1D271FD-4914-3FD9-9F85-2C281F8B8147`, SHA256 `e7a5e58ec422eef9dcb53b26d73d5df09e93da6141f67c39766aa039476ffaa9`. Proprietary binaries stay outside this repository.

## Exact Wallet boundaries (VM address, no ASLR)

- `QQWalletPreGrapHBResultViewController -handleHBGrapResult:` `v24@0:8@16`, IMP `0x5687c8`: writes the received dictionary to `grapHBData.grapResultData`; `state == 0` takes success animation (0x5688e8), then dismisses pre-open UI and opens details via `QQWalletSceneManager +openHBDetailViewController:isPresent:`.
- `QQWalletGrapHBData -aioData` `@16`, 0x574118; `QQWalletGrapHBAIOData -listId` `@16`, 0x57a0a4. These relate the response to the same pending native bill; identifiers are compared in memory only, never logged.
- `QQWalletGrapHBData -receiveHBInfo` 0x5740d8 returns `grapResultData["recv_object"]`. `QQWalletGrapHBResultView -showHBMoney` 0x540b2c reads its `amount` numeric value and only displays a positive amount. Success requires both native `state == 0` and a strictly positive received amount; malformed/missing/negative states do not authorize return.
- Native detail class `CFT_UIRedGiftDetailBaseViewController` has `-listid` `@16` (0x620150), `-customNavigationView` `@16` (0x61c624).
- `CFT_UIRedGiftCustomNavigationView -leftButton` `@16` (0x6491fc) registers itself to its button's TouchUpInside with `-leftButtonClick:` `v24@0:8@16` (0x6494cc). That forwards to native `-didLeftButtonClick:` and preserves the app's custom navigation/cleanup. No guessed pop/dismiss is used by the production return path.

## Changes

A narrow typed observer forwards `handleHBGrapResult:` exactly once and latches only a matching pending bill's native outcome. UUID/module guards fail closed. Old same-message-model confirmation remains as a fallback for native inline variants. The native error latch vetoes both paths; a normal route callback alone is never success.

On confirmed native success, discover only a new visible native detail controller with the same bill, verify the registered native left-button target/action/ABI and hit visibility, send one original control event, then separately observe the detail disappearing and origin presenter returning. `returned` is distinct from `effect-observed`. Unconfirmed/still-visible UI prevents overlapping routes; manual native button activity cancels the remaining queue.

New records in one batch or while busy are retained in an in-memory FIFO (32 max / 30s max). Recheck owner, foreground epoch, options, original record identity, bill, age, UI and return presenter before dispatch. De-duplicate pending and attempted bills. No cache of message text/media is written; no server retries or duplicate claim attempts are introduced. The callback UI settle interval is 0.15s instead of an arbitrary 1s; origin/owned-page guards remain mandatory.

## Background status

Not implemented in this initial two-fix candidate. The prior main-only evidence was insufficient; the newly supplied Wallet is being independently inspected for a real non-UI request path. Do not label this commit as fixing background. Never pass nil rootVC to the front-end route or remove foreground guards as a substitute. No keepalive, fake audio/push or force wake.

## Validation

Focused source tests and real UIKit cases cover unchanged original receipt model with native positive response, native error, wrong bill, missing amount, actual registered back event, modal/push result return effect, same-batch second packet, busy second delivery, duplicate suppression and manual queue cancellation. UIKit uses exact class-name doubles with UUID guarding disabled only by `TIMANTIRECALL_UI_TEST`; these fixtures cannot prove TIM device success. Real build and target-device verification are separate stages.
