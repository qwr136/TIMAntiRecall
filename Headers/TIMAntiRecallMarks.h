#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// State contains only message/account identifiers and capture timestamps.
@interface TIMAntiRecallMarkStore : NSObject
- (instancetype)initWithURL:(NSURL *)url persistent:(BOOL)persistent;
- (void)timantirecall_setPersistent:(BOOL)persistent;
- (BOOL)timantirecall_flush:(NSError **)error;
- (NSError *)timantirecall_lastError;
- (NSArray<NSDictionary *> *)timantirecall_eventsForOwner:(NSString *)owner;
- (NSDictionary *)timantirecall_eventForIdentity:(NSDictionary *)identity;
- (NSDictionary *)timantirecall_displayCandidateForIdentity:(NSDictionary *)identity;
- (void)timantirecall_suppressDisplayForEvent:(NSDictionary *)event;
- (void)timantirecall_addEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner;
- (void)timantirecall_addEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner capturedAt:(NSTimeInterval)time;
- (BOOL)timantirecall_containsIdentity:(NSDictionary *)identity;
- (BOOL)timantirecall_containsRecallEventForIdentity:(NSDictionary *)identity;
- (void)timantirecall_forgetEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner;
- (void)timantirecall_clear;
@end
FOUNDATION_EXPORT TIMAntiRecallMarkStore *timantirecall_sharedMarks(void);
FOUNDATION_EXPORT void timantirecall_prepareState(void);
FOUNDATION_EXPORT BOOL timantirecall_installColdRecallProtection(void);
FOUNDATION_EXPORT NSArray<NSDictionary *> *timantirecall_recallEvents(NSData *data);
FOUNDATION_EXPORT BOOL timantirecall_forgetOwnRecall(NSData *data, NSString *owner);
FOUNDATION_EXPORT BOOL timantirecall_recallEventMatchesIdentity(NSDictionary *event, NSDictionary *identity);
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
