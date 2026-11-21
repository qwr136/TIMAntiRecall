#pragma once
#import "TIMAntiRecallFixture.h"
#import "TIMAntiRecallReplayRichFixture.h"
@interface NTAIOContact : NSObject
@property(nonatomic) int64_t chatType;
@property(nonatomic,copy) NSString *uin,*groupCode,*guildID;
- (OCContact *)convertToOCContact;
@end
@interface TIMAntiRecallReplayPhotoProbe : NSObject
@property(nonatomic) NSUInteger timantirecall_calls;
@property(nonatomic) int32_t timantirecall_subtype;
@property(nonatomic,strong) NSData *timantirecall_bytes;
@property(nonatomic,copy) NSString *timantirecall_path;
@property(nonatomic,strong) OCContact *timantirecall_contact;
@property(nonatomic,strong) id timantirecall_additional;
@property(nonatomic,copy) void(^timantirecall_completion)(int32_t,NSString *);
+ (instancetype)timantirecall_shared;
@end
@interface QQMsgService (TIMAntiRecallPhotoFixture)
- (void)sendPicMsg:(NTAIOContact *)contact sourcePath:(NSString *)path additionalMsg:(id)additional picSubType:(int32_t)subtype callBack:(void(^)(int32_t,NSString *))callback;
@end
