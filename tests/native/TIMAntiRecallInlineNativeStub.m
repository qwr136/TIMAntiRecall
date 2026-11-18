#import "TIMAntiRecallMarks.h"
#ifdef TIMANTIRECALL_NATIVE_TEST
BOOL timantirecall_installPreferences(void) { return NO; }
BOOL timantirecall_installInlineIndicator(void) { return NO; }
void timantirecall_markIntercepted(NSData *data,NSString *owner) {
    // Real identity parser/store/session code is tested separately; UIKit runs in the simulator app.
    (void)data;(void)owner;
}
#endif
