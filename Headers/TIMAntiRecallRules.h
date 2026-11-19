#pragma once
#import <Foundation/Foundation.h>

@interface TIMAntiRecallRules : NSObject
- (instancetype)initWithURL:(NSURL *)url;
- (NSDictionary *)timantirecall_policyForOwner:(NSString *)owner;
- (BOOL)timantirecall_savePolicy:(NSDictionary *)policy owner:(NSString *)owner error:(NSError **)error;
@end

FOUNDATION_EXPORT TIMAntiRecallRules *timantirecall_rules(void);
FOUNDATION_EXPORT NSString *timantirecall_ruleChatKey(NSDictionary *identity);
FOUNDATION_EXPORT BOOL timantirecall_rulesMatchChat(NSDictionary *policy, NSDictionary *identity, BOOL reply);
FOUNDATION_EXPORT BOOL timantirecall_rulesHideText(NSDictionary *policy, NSString *text);
FOUNDATION_EXPORT NSString *timantirecall_rulesReply(NSDictionary *policy, NSDictionary *identity,
                                                   NSString *text, BOOL mentioned, NSInteger minute);
FOUNDATION_EXPORT NSString *timantirecall_plainRecordText(id record, NSString *owner, BOOL *mentioned);

@interface TIMAntiRecallReplyGate : NSObject
// Capped, process-local dedup, per-chat cooldown, and a global rate ceiling.
- (BOOL)timantirecall_reserve:(NSDictionary *)identity cooldown:(NSTimeInterval)cooldown now:(NSTimeInterval)uptime;
@end
