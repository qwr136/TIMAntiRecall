#pragma once
#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

// Returns UUID only for one structurally valid arm64 MH_EXECUTE image header.
FOUNDATION_EXPORT NSString *timantirecall_uuidForMainExecutableHeader(const struct mach_header *header);
