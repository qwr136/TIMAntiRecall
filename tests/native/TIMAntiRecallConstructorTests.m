#import <Foundation/Foundation.h>
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
            ![log containsString:@"identity-rejected"] || [log containsString:@"hook-installed"]) {
            NSLog(@"FAIL real constructor bootstrap/identity rejection"); return 2;
        }
        NSRange first=[log rangeOfString:@"constructor-enter"];
        NSRange rejection=[log rangeOfString:@"identity-rejected"];
        if (first.location>=rejection.location) return 3;
        NSLog(@"PASS real macOS constructor executed before main and logged rejected identity; device untested");
    }
    return 0;
}
