#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallBootstrap.h"
#include <stdio.h>

static void timantirecall_identityValue(const char *name, id value) {
    char safe[112], event[192];
    const char *text = [value isKindOfClass:NSString.class] ? [(NSString *)value UTF8String] : NULL;
    timantirecall_bootstrapSafeValue(text, safe, sizeof(safe));
    snprintf(event, sizeof(event), "identity %s=%s", name, safe);
    timantirecall_bootstrapEvent(event);
}

BOOL timantirecall_startupWithIdentity(NSDictionary *identity, NSString *uuid, void (^install)(void)) {
    if (![identity isKindOfClass:NSDictionary.class]) {
        timantirecall_bootstrapEvent("identity-rejected reason=metadata-missing");
        return NO;
    }
    id bundle = identity[@"CFBundleIdentifier"];
    id version = identity[@"CFBundleShortVersionString"];
    id build = identity[@"CFBundleVersion"];
    id executable = identity[@"CFBundleExecutable"];
    // These are fixed application build metadata, never account or message data.
    timantirecall_identityValue("bundle", bundle);
    timantirecall_identityValue("version", version);
    timantirecall_identityValue("build", build);
    timantirecall_identityValue("executable", executable);
    timantirecall_identityValue("uuid", uuid);
    NSString *reason = timantirecall_targetRejectionReason(bundle, version, build, executable, uuid);
    if (reason) {
        char event[160];
        snprintf(event, sizeof(event), "identity-rejected reason=%s", reason.UTF8String);
        timantirecall_bootstrapEvent(event);
        return NO;
    }
    timantirecall_bootstrapEvent("identity-accepted");
    timantirecall_logEvent(@"loaded-TIM-4.1.0.81");
    if (install) install();
    return YES;
}
