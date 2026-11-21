#pragma once
#import "TIMAntiRecallReplayPhotoFixture.h"
// Minimal properties read by the native-reference plan; types match locked QQ metadata.
@interface OCVideoElement : NSObject
@property(nonatomic,copy) NSString *videoMd5,*fileUuid;
@property(nonatomic,strong) NSNumber *invalidState;
@property(nonatomic) uint64_t fileSize;
@property(nonatomic) int32_t fileTime;
@end
@interface TIMAntiRecallVideoForwardProbe : NSObject
@property(nonatomic) NSUInteger timantirecall_calls,timantirecall_getterCalls;
@property(nonatomic,strong) NSArray *timantirecall_ids,*timantirecall_destinations;
@property(nonatomic,strong) OCContact *timantirecall_source;
@property(nonatomic,strong) id timantirecall_attributes;
@property(nonatomic,copy) void(^timantirecall_completion)(int32_t,NSString *,NSDictionary *);
@property(nonatomic) NSInteger timantirecall_handlerMode;
@property(nonatomic) BOOL timantirecall_onMain;
+ (instancetype)timantirecall_shared;
- (void)forwardMsgWithMsgIds:(NSArray *)ids srcContact:(OCContact *)source dstContacts:(NSArray *)destinations msgAttributeInfos:(id)attributes cb:(void(^)(int32_t,NSString *,NSDictionary *))completion;
@end
@interface QQMsgService (TIMAntiRecallVideoFixture)
- (id)getMsgSenderHandlerWithcontact:(NTAIOContact *)contact;
@end
