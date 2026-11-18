#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSError *timantirecall_storageError(NSString *message);
FOUNDATION_EXPORT id timantirecall_readState(NSURL *url, NSError **error);
FOUNDATION_EXPORT BOOL timantirecall_writeState(NSDictionary *value, NSURL *url, NSError **error);
FOUNDATION_EXPORT BOOL timantirecall_removeState(NSURL *url, NSError **error);
