# Native open step and legacy log removal

Baseline: 3.50 (`934a82e50ad695f342fbe8c4f46b42772bfe24e8`). User has stopped further force-reopen work. This revision changes only the packet open step, optional packet diagnostics, and the two legacy log sinks. It does not change recall matching or display code.

## Device evidence

The user's 2026-11-19 trace contains `redpack-monitor-installed`, `redpack-private-observed`, `redpack-route-available`, and `redpack-native-route-attempted`. User confirmed and supplied a screenshot of a native red-packet card with a visible 開 control over the TIM chat list. The user must tap it. This establishes that 3.50's route can show the receive page but is not a complete automatic-open flow. Missing completion does not establish that a claim failed or a server request ran.

## Open implementation

Only the native route initiated by this plugin arms the one-shot step. It snapshots the current view tree, then observes newly added, visible, enabled UIControls for at most six bounded scans during four seconds. It requires exactly one native TouchUpInside binding, a standard void UIKit action signature, implementation/class origin in the same image as the actual Wallet service, and an explicit accessible label or button title equal to 开 / 開 / 开红包 / 開紅包. Existing controls, ambiguous multiple candidates, stale account/foreground/setting tokens, hidden/covered controls and incomplete tree scans are rejected. It sends exactly one native UIControl event; it does not guess private selectors, inject coordinate touches, or advance any subsequent payment/security confirmation. Any intervening native control action cancels pending automation, while forwarding the original action once.

The supplied main Mach-O lacks the actual dynamically loaded Wallet UI class implementation. This adapter deliberately fails closed for an image-only/inaccessible control without an explicit semantic label. Optional packet logs record only runtime classes, action names, method encodings and image basenames for the new controls; a manual click during the same bounded context can identify the missing native binding without logging text, credentials, account, message IDs or packet contents. Dispatch/return is not proof of receipt or settlement. The actual TIM Wallet UI and successful receipt still require device testing.

## Logs

Delivered builds no longer write `TIMAntiRecall-bootstrap.log` (including TMPDIR fallback/syslog) or `TIMAntiRecall.log`. The early writer is compiled only into isolated native regression executables. A new default-build test compiles the production C path and verifies no file or directory is created. The native/constructor test-only sink is not evidence of production logging. Existing device files are not modified or removed. Optional `TIMAntiRecall-packets.log` remains under its current account-level diagnostics switch.

## Regression

The real UIKit fixture now presents a native 開 UIButton before invoking the receive completion, and requires the actual production helper to dispatch it for a fresh private and group packet. Separate tests reject pre-existing/open/payment controls, stale tokens and ambiguous controls, and verify manual forwarding without a duplicate automatic event. Native and source tests remain build gates. No device success is claimed by those fixtures.
