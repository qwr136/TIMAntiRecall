# Persistence, per-chat switches and capture time

Baseline: accepted 0.80 / f6c3ef6f711a4c8a22ed1b6ee50079831b169e08. Scope: only restart-retained recall marks, per-chat anti-recall switches, capture-time inspection and in-app settings. Quick phrases, drafts and todos are not included.

## Defaults and entry

Existing anti-recall remains enabled; mark persistence defaults on. The original red frame + 已撤回 appearance is retained by default; clock text is optional and defaults off. In TIM Settings, the top-right 防撤回 button opens a grouped card panel. Private/group chat detail pages also get the button and, when the actual conversation can be correlated, a current-chat switch. Existing navigation items remain untouched. No PreferenceLoader, substrate or jailbreak dependency is introduced.

The three own viewDidAppear: hooks are v20@0:8B16. Locked TIM4.1.0.81 static evidence: QQSettingsViewController IMP102de7510, QQChatSettingViewController100a9a8e0, QQGroupSettingViewController101f92954. Private uin getter @16 IMP100aacc20, group groupCode @16 IMP101f98e4c. UIKit runtime validation rejects wrong classes, inherited methods or signatures. Original animated BOOL is forwarded exactly once. Each entry target weakly references its host. New selectors/classes are plugin-prefixed.

## Storage and policy

Inside TIM's own sandbox: Library/Application Support/TIMAntiRecall/preferences.plist and marks.plist. This explicitly differs from jailbreak/global preferences paths. Settings have one panel writer; receive hooks read only immutable in-memory snapshots. No networking, system clipboard, login tickets or message bodies. Files are binary plists, atomic replacements, bounded to8MiB; regular-file/type checks reject symlinks, corrupt files are not silently overwritten. iOS writes use CompleteUntilFirstUserAuthentication protection; mode0600 and backup-exclusion are requested. These attributes do not constitute independent encryption.

Marks retain the same owner/kind/peer-or-group/seq/author and optional time/random matching as0.80. Only normalized identity fields and first capturedAt are persisted, at most4096 entries total; oldest entries are evicted. Duplicate notifications retain the first capture timestamp. One serial I/O queue coalesces changes instead of accumulating snapshots. Failures are visible in the panel. Closing persistence asks for confirmation and removes the disk archive while retaining process-memory marks. A crash immediately before a pending write completes can still lose that latest mark.

Per-chat switches are account-scoped; private UIDs and group numbers use different namespaces. Current-chat numeric QQ aliases come only from typed OCMsgRecord.peerUin observed at actual row binding/conversion; ambiguity refuses modification rather than guessing by nickname/text/index. The management list contains observed conversations and explicitly configured entries (up to1024). An unvisited conversation may not be listed until opened. Global off forwards all recalls; a disabled identifiable chat forwards its original packet/arguments once, never creates a new mark. Old retained messages are not deleted. Re-enabling cannot recover recalls TIM already processed while disabled. Scope parsing is independent of optional author metadata so a disabled group is not accidentally blocked just because decoration extraction fails. Unknown owner/scope retains0.80 protection rather than applying another account's preference.

Capture time is recorded at the plugin interception call before dispatch to main. The record page shows full local date/time and sequence, filtered to the current account (and current chat when opened from details). Optional row text is 已撤回 · HH:mm:ss. It is not sender time or authoritative server time.

## Evidence and limits

CI must execute real Foundation seed/restore/negative modes in three processes, including corruption, symlinks, timestamp preservation, bounds and cross-account isolation. UIKit tests use real setting controls, navigation entry actions, private/group forwarding, time labels, weak/lifecycle regression, and a second genuinely different simulator app PID restoring a row before any new push. The driver and release receipt require all reports and a settings screenshot tied to current source/run/attempt.

Simulator host models remain synthetic. Actual TIM settings navigation, private mapping, filesystem permissions, cold relaunch and final device pixels require user acceptance. Only marks for new captures can be saved;0.80's process-only marks cannot be recovered after that old process exits. Saving identifiers cannot restore a message TIM later removes or expired media.0.80 source/release stays available as rollback.
