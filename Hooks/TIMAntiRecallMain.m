#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallBootstrap.h"
#import "TIMAntiRecallImage.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallPreferencesEntry.h"
#import <mach-o/dyld.h>
#import <crt_externs.h>
#import <mach-o/loader.h>
#include <stdio.h>

#if !defined(TIMANTIRECALL_NATIVE_TEST) || defined(TIMANTIRECALL_CONSTRUCTOR_TEST)
static NSString *timantirecall_mainUUID(void) {
    const struct mach_header *header = (const struct mach_header *)_NSGetMachExecuteHeader();
    if (!header) { timantirecall_bootstrapEvent("main-execute-header-missing"); return nil; }
    char event[192];
    snprintf(event,sizeof(event),"main-execute-header filetype=%u cpu=%u subtype=%u",
             header->filetype,(unsigned)header->cputype,(unsigned)header->cpusubtype);
    timantirecall_bootstrapEvent(event);
    NSString *uuid=timantirecall_uuidForMainExecutableHeader(header);
    timantirecall_bootstrapEvent(uuid?"main-execute-uuid-valid":"main-execute-uuid-invalid");
    return uuid;
}

static void timantirecall_attemptUIInstall(unsigned attempt) {
    BOOL installed=timantirecall_installInlineIndicator();
    BOOL preferences=timantirecall_installPreferences();
    if((installed && preferences) || attempt>=10)return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        timantirecall_attemptUIInstall(attempt+1);
    });
}
static void timantirecall_attemptInstall(unsigned attempt) {
    timantirecall_prepareState();
    timantirecall_installLegacyBridge();
    Class target = objc_getClass("OCIQQNTWrapperSession");
    timantirecall_installSessionTracking(target);
    if (timantirecall_installOnClass(target)) {
        timantirecall_bootstrapEvent("hook-installed-before-kernel");
        timantirecall_logEvent(@"installed-before-kernel");
        dispatch_async(dispatch_get_main_queue(),^{ timantirecall_attemptUIInstall(0); });
        return;
    }
    if (attempt == 0) timantirecall_bootstrapEvent(target ? "hook-rejected-method-or-ABI retry=1" : "hook-class-missing retry=1");
    if (attempt >= 30) {
        timantirecall_bootstrapEvent(target ? "hook-final-rejected-method-or-ABI" : "hook-final-class-missing");
        timantirecall_logEvent(@"install-rejected-missing-class-or-ABI"); return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        timantirecall_attemptInstall(attempt + 1);
    });
}

__attribute__((constructor)) static void timantirecall_initialize(void) {
    // First observable side effect precedes Foundation and all identity checks.
    timantirecall_bootstrapEvent("constructor-enter diagnostic=startup-2");
    @autoreleasepool {
        timantirecall_bootstrapEvent("foundation-begin");
        const struct mach_header *image0 = _dyld_get_image_header(0);
        if (image0) {
            char event[192];
            snprintf(event, sizeof(event), "image0 filetype=%u cpu=%u subtype=%u", image0->filetype,
                     (unsigned)image0->cputype, (unsigned)image0->cpusubtype);
            timantirecall_bootstrapEvent(event);
        }
        NSBundle *bundle = NSBundle.mainBundle;
        timantirecall_startupWithIdentity(bundle.infoDictionary, timantirecall_mainUUID(), ^{
            timantirecall_attemptInstall(0);
        });
    }
}
#endif
