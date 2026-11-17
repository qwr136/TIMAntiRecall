#import <Foundation/Foundation.h>
#import "TIMAntiRecallImage.h"
#import <mach-o/ldsyms.h>
#import <mach-o/dyld.h>
#include <stdlib.h>

// This executable intentionally has the wrong identity. Its constructor must
// write evidence and reject installation before main(), rather than staying silent.
int main(void) {
    @autoreleasepool {
        const char *home=getenv("HOME");
        if (!home) return 1;
        NSString *path=[[NSString stringWithUTF8String:home] stringByAppendingPathComponent:@"Documents/TIMAntiRecall/TIMAntiRecall-bootstrap.log"];
        NSString *log=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        if (![log containsString:@"constructor-enter"] || ![log containsString:@"foundation-begin"] ||
            ![log containsString:@"identity-rejected"] || ![log containsString:@"main-execute-header filetype=2"] ||
            ![log containsString:@"main-execute-uuid-valid"] || [log containsString:@"hook-installed"]) {
            NSLog(@"FAIL real constructor bootstrap/identity rejection"); return 2;
        }
        NSRange first=[log rangeOfString:@"constructor-enter"];
        NSRange rejection=[log rangeOfString:@"identity-rejected"];
        if (first.location>=rejection.location) return 3;
        NSString *expected=timantirecall_uuidForMainExecutableHeader((const struct mach_header *)&_mh_execute_header);
        if (!expected || ![log containsString:[@"identity uuid=" stringByAppendingString:expected]]) return 4;
        if (getenv("TIMANTIRECALL_REQUIRE_INSERTED_FIRST")) {
            const struct mach_header *first=_dyld_get_image_header(0);
            if (!first || first->filetype!=MH_DYLIB) return 5;
            if (![log containsString:@"image0 filetype=6"]) return 6;
            NSLog(@"PASS inserted dylib at image0 did not change main executable UUID");
        }
        NSLog(@"PASS real macOS constructor executed before main and logged rejected identity; device untested");
    }
    return 0;
}
