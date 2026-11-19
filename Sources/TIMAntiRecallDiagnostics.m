#import "TIMAntiRecallRuntime.h"

// Legacy diagnostic sink is intentionally silent in the delivered library.
// Keep the call boundary so disabling logs cannot change recall decisions.
void timantirecall_logEvent(NSString *event) {
    (void)event;
}
