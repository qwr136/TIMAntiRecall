#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallBootstrap.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <stdio.h>

#if !defined(TIMANTIRECALL_NATIVE_TEST) || defined(TIMANTIRECALL_CONSTRUCTOR_TEST)
static NSString *timantirecall_mainUUID(void) {
    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
    if (!header || header->magic != MH_MAGIC_64) return nil;
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *end = cursor + header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; index++) {
        if (cursor + sizeof(struct load_command) > end) return nil;
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor)) return nil;
        if (command->cmd == LC_UUID && command->cmdsize == sizeof(struct uuid_command)) {
            const struct uuid_command *uuid = (const struct uuid_command *)cursor;
            return [[NSUUID alloc] initWithUUIDBytes:uuid->uuid].UUIDString;
        }
        cursor += command->cmdsize;
    }
    return nil;
}

static void timantirecall_attemptInstall(unsigned attempt) {
    Class target = objc_getClass("OCIQQNTWrapperSession");
    if (timantirecall_installOnClass(target)) {
        timantirecall_bootstrapEvent("hook-installed-before-kernel");
        timantirecall_logEvent(@"installed-before-kernel");
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
