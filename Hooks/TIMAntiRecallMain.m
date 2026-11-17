#import "TIMAntiRecallRuntime.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <stdatomic.h>

#ifndef TIMANTIRECALL_NATIVE_TEST
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
        timantirecall_logEvent(@"installed-before-kernel");
        return;
    }
    if (attempt >= 30) { timantirecall_logEvent(@"install-rejected-missing-class-or-ABI"); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        timantirecall_attemptInstall(attempt + 1);
    });
}

__attribute__((constructor)) static void timantirecall_initialize(void) {
    @autoreleasepool {
        NSBundle *bundle = NSBundle.mainBundle;
        if (!timantirecall_matchesTarget(bundle.bundleIdentifier,
                [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                [bundle objectForInfoDictionaryKey:@"CFBundleVersion"],
                [bundle objectForInfoDictionaryKey:@"CFBundleExecutable"], timantirecall_mainUUID())) return;
        timantirecall_logEvent(@"loaded-TIM-4.1.0.81");
        // Objective-C classes in the main executable are normally registered
        // before constructors. Retry only on startup when the class is absent.
        timantirecall_attemptInstall(0);
    }
}
#endif
