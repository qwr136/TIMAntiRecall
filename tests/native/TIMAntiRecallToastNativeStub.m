#import "TIMAntiRecallToast.h"

#ifdef TIMANTIRECALL_NATIVE_TEST
void timantirecall_showToast(void) {
    // macOS Foundation runtime doubles cannot load UIKit; iOS build owns the real UI implementation.
}
#endif
