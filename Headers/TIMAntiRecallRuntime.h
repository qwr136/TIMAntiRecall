#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

FOUNDATION_EXPORT BOOL timantirecall_installOnClass(Class target);
FOUNDATION_EXPORT void timantirecall_logEvent(NSString *event);
FOUNDATION_EXPORT BOOL timantirecall_matchesTarget(NSString *bundle, NSString *version,
                                                  NSString *build, NSString *executable,
                                                  NSString *uuid);
