#import "TIMAntiRecallImage.h"
#import <mach/machine.h>
#include <stdbool.h>

// The ABI is LP64 on all supported runtime images.
_Static_assert(sizeof(struct mach_header_64)==32, "unexpected Mach-O header width");

NSString *timantirecall_uuidForMainExecutableHeader(const struct mach_header *header) {
    if (!header || header->magic != MH_MAGIC_64 || header->filetype != MH_EXECUTE ||
        header->cputype != CPU_TYPE_ARM64 ||
        (header->cpusubtype & ~CPU_SUBTYPE_MASK) != CPU_SUBTYPE_ARM64_ALL ||
        header->sizeofcmds < sizeof(struct uuid_command) || header->sizeofcmds > (16U * 1024U * 1024U) ||
        header->ncmds == 0 || header->ncmds > header->sizeofcmds / sizeof(struct load_command)) return nil;
    const struct mach_header_64 *header64=(const struct mach_header_64 *)header;
    const uint8_t *cursor = (const uint8_t *)(header64 + 1);
    const uint8_t *end = cursor + header->sizeofcmds;
    bool found = false;
    NSUUID *uuid = nil;
    for (uint32_t index = 0; index < header->ncmds; index++) {
        if (cursor > end || (size_t)(end - cursor) < sizeof(struct load_command)) return nil;
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command) || command->cmdsize % 8 != 0 ||
            command->cmdsize > (size_t)(end - cursor)) return nil;
        if (command->cmd == LC_UUID) {
            if (found || command->cmdsize != sizeof(struct uuid_command)) return nil;
            const struct uuid_command *uuidCommand = (const struct uuid_command *)cursor;
            uuid = [[NSUUID alloc] initWithUUIDBytes:uuidCommand->uuid];
            found = uuid != nil;
        }
        cursor += command->cmdsize;
    }
    if (cursor != end || !found) return nil;
    return uuid.UUIDString;
}
