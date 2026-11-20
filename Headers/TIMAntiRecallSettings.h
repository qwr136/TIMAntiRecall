#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSNotificationName const TIMAntiRecallSettingsChangedNotification;
FOUNDATION_EXPORT NSNotificationName const TIMAntiRecallStateChangedNotification;
FOUNDATION_EXPORT BOOL timantirecall_validUID(id value);
FOUNDATION_EXPORT NSString *timantirecall_scopeKey(NSDictionary *identity);
FOUNDATION_EXPORT NSURL *timantirecall_stateURL(NSString *filename);
@interface TIMAntiRecallSettings : NSObject
- (instancetype)initWithURL:(NSURL *)url;
- (BOOL)timantirecall_enabled;
- (BOOL)timantirecall_persistMarks;
- (BOOL)timantirecall_showTime;
- (BOOL)timantirecall_autoClaimRedPackets;
- (BOOL)timantirecall_claimOwnRedPackets;
- (BOOL)timantirecall_messageReplay;
- (BOOL)timantirecall_packetDiagnostics;
- (BOOL)timantirecall_setPacketOption:(NSString *)key enabled:(BOOL)enabled owner:(NSString *)owner error:(NSError **)error;
- (BOOL)timantirecall_enabledForChat:(NSDictionary *)chat;
- (BOOL)timantirecall_shouldBlockData:(NSData *)data owner:(NSString *)owner;
- (BOOL)timantirecall_updateOptions:(NSDictionary *)changes error:(NSError **)error;
- (BOOL)timantirecall_setChat:(NSDictionary *)chat enabled:(BOOL)enabled error:(NSError **)error;
- (void)timantirecall_observeChat:(NSDictionary *)identity;
- (NSArray<NSDictionary *> *)timantirecall_chatsForOwner:(NSString *)owner;
- (NSDictionary *)timantirecall_chatForAlias:(NSString *)alias kind:(unsigned)kind owner:(NSString *)owner;
- (NSError *)timantirecall_lastError;
@end
FOUNDATION_EXPORT TIMAntiRecallSettings *timantirecall_settings(void);
FOUNDATION_EXPORT BOOL timantirecall_shouldBlockRecall(NSData *data, NSString *owner);
