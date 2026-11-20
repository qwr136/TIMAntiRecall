# No ordinary packet popup; native execution in foreground/background

Baseline: user-accepted 4.60, `c41642dfa1ce88797297c86afe773cfbbf576720`.

Scope: fresh supported private/group ordinary packets received through TIM's real message callback. Do not present the `開` controller or its grey root view at all. Keep native pre-open, token generation, eligibility/risk handling, claim response and state update. Allow processing in a natural iOS background execution window; no wake, background task, audio or keep-alive is added to production. Do not claim support for suspension or force quit.

## Minimal native boundary

The current decrypted Wallet image is ARM64, UUID `E1D271FD-4914-3FD9-9F85-2C281F8B8147`. Existing `PacketWallet` continues checking its full image UUID and ABI; the new `PacketSilent` checks every new private method belongs to that image.

1. Original `NTRedPackRouterService handleRedPackViewClickWithRootVC:msgRecord:gesture:completion:` receives the original record. The callback ABI remains `void (^)(NSDictionary *, NSError *)`.
2. `QQWallet -grabHB:params:completion:` (`0x477a14`, `v40@0:8@16@24@?32`) is intercepted only during this plugin's synchronous route, on the verified shared Wallet instance, with native `params.listid` equal to the authorized bill. The native `isGotoNewGrapProcess:` and `isNeedGotoPreGrapProcess:` predicates must both permit the audited pre-open branch. They are not overridden. Unknown legacy/non-pre-open branches fail closed rather than being turned into custom requests.
3. That original method still runs once. `preGrapHBProcess:completion:` still creates native data, gets native login credentials, performs the native pre-open request and passes its original response through risk/real-name handling. Only its owned visual `showLoading` call is suppressed.
4. Normal pre-open state 16 reaches `+[QQWalletSceneManager presentTransparentViewController:]` (`0x512318`, `v24@0:8@16`). For the exact native `QQWalletPreGrapHBResultViewController`, identical service model, exact bill and still-identical native pre callback, the original presenter is not invoked. Thus neither its native navigation container nor red/grey root enters any window. This is not alpha hiding or dismiss-after-present.
5. Load that unpresented native controller's own view, then call its real `onOpenButtonClick:` (`0x568554`, `v24@0:8@16`) once with its real `QQWalletPreOpenHBView`. Disassembly proves the parameter is only retained/released, while the method itself obtains `generateGrapHBParam`, copies the real `pre_grap_token` from pre-open data, and invokes the normal `grapHBAfterPreGrapProcess:isNeedDefaultLoading:completion:`. No protocol parameters, token, amount or qualification outcome are manufactured by this plugin.
6. Original `handleHBGrapResult:` and all native state updates stay intact. The already-audited success animation's known global completion `image+0xc00158` only routes to details; only that completion on this associated off-window controller is omitted. Manual controllers keep their original presentation and detail completion.
7. Final native callback is consumed asynchronously on main after the native stack returns. The next attempt waits for both service callbacks and Wallet `_grabCompletionBlock` (`@?`, runtime-verified `+0x30`), and `isPaying` (`B16`, `0x47e284`, `+0x38`) to be idle. A wait timeout never clears an outstanding native claim, closes its receipt consumer, or claims success. A late receipt can still confirm its actual amount.

The only explicit slot retirement is the identical, already-resolved and never-submitted owned pre callback after cancellation. It is never applied before the pre response, to a claim slot, or to another caller. All diagnostic phases are fixed labels; no identifiers, message text, amount, token or auth value is logged or saved.

## UI and lifecycle

Keep 4.60's exact amount formatter, centered noninteractive label and three-second timer. Only a submitted same-bill final native `state==0`, no NSError, and a valid positive received amount supplies a toast. Background receipts do not place overlays into another app or save a delayed amount toast. Manual claims, verification/unknown results and settings/account changes must not produce an automatic success label.

No background notification may be mistaken for a full message callback. The ingress observes both foreground and background executions but still applies current account, both preferences, live/online/non-imported freshness, supported type, full record identity, bill de-duplication and bounded FIFO. UIKit presenter discovery is only required when the app is active, so manual payment/verification pages still block new foreground work. iOS inactive transition is not treated as a background execution opportunity.

## Verification boundaries

Source gates are structural. Actual production UIKit component tests use native-facing runtime doubles, including the low Wallet slot at its real offset. They require no presenter calls during automatic pre-open, exact native action/token usage, private/group/own switches, errors/unknown followed by further attempts, manual UI and details, lower-slot contention, late receipts, and existing amount timer/touch/lifecycle checks. The existing real simulator scene switch now injects two message callbacks after `UIApplicationStateBackground`, requires both native callback chains and all slots to finish before the driver is allowed to resume the app, and checks no modal/amount overlay was presented.

This simulator is not proprietary TIM or a real server. Actual TIM view-loading side effects, normal channels, wallet-ready state, native verification behavior and timing across natural background windows remain device acceptance items. Do not substitute source or Actions success for device acceptance. Keep 4.60 available for rollback; no stable branch merge or formal Release is implied.

## Manual/native slot contention

Removing the blocking popup exposes ordinary user interaction while an automatic claim is still in flight. A manual `QQWallet grabHB:params:completion:` call on the same Wallet therefore waits as one bounded pending native invocation, rather than overwriting the auto claim's shared slots. Once all owned native slots are idle, that exact manual invocation (original root, params and completion) runs before any next automatic claim. Account change, leaving the foreground, a new unrelated wallet operation or an additional manual tap causes that deferred caller to receive an error instead of starting a stale/overlapping request. Manual presentation, eligibility and details otherwise remain native. Dedicated UIKit coverage holds an auto callback, requests manual open, confirms no slot replacement, releases auto, then requires manual native UI, callback and details exactly once.
