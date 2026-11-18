#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Identity-only state. No message text, media, credentials or private data is persisted.
@interface TIMAntiRecallMarkStore : NSObject
- (void)timantirecall_addEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner;
- (BOOL)timantirecall_containsIdentity:(NSDictionary *)identity;
- (void)timantirecall_clear;
@end
FOUNDATION_EXPORT NSArray<NSDictionary *> *timantirecall_recallEvents(NSData *data);
FOUNDATION_EXPORT NSDictionary *timantirecall_recordIdentity(id record, NSString *owner);
FOUNDATION_EXPORT NSString *timantirecall_currentAccount(void);
FOUNDATION_EXPORT BOOL timantirecall_methodTypes(Method method, const char *result,
                                                 unsigned argumentCount, const char * const *arguments);
FOUNDATION_EXPORT void timantirecall_installSessionTracking(Class target);
FOUNDATION_EXPORT NSString *timantirecall_sessionOwner(id session);
FOUNDATION_EXPORT BOOL timantirecall_installLegacyBridge(void);
FOUNDATION_EXPORT NSDictionary *timantirecall_legacyRowIdentity(id model, NSString *owner);
FOUNDATION_EXPORT BOOL timantirecall_installInlineIndicator(void);
FOUNDATION_EXPORT void timantirecall_markIntercepted(NSData *data, NSString *owner);
