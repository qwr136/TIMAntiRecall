#pragma once
#import "TIMAntiRecallFixture.h"
#import "TIMAntiRecallReplayRichFixture.h"
@interface TIMAntiRecallReceivedPic : OCPicElement
@property(nonatomic,copy) NSString *timantirecall_originalPath;
@property(nonatomic) NSUInteger timantirecall_cacheCalls;
@property(nonatomic) BOOL timantirecall_createRequested;
- (NSString *)fetchOriginalImgPathWithCreateFolder:(BOOL)create;
@end
@interface TIMAntiRecallReceivedPicWrongABI : OCPicElement
@property(nonatomic) NSUInteger timantirecall_wrongCalls;
- (NSString *)fetchOriginalImgPathWithCreateFolder:(int64_t)create;
@end
@interface NTAIOContact : NSObject
@property(nonatomic) int64_t chatType;
@property(nonatomic,copy) NSString *uin,*groupCode,*guildID;
- (OCContact *)convertToOCContact;
@end
@interface NTRecordConverter (TIMAntiRecallNativePhoto)
+ (QQAIOMsgModel *)recordConvertAIOMsgModel:(OCMsgRecord *)record;
@end
@interface QQRichMediaPhotoBrowserChatImageAgent : NSObject
@property(nonatomic,copy) NSString *originalImagePath;
+ (void)timantirecall_configureOriginalDownloadPath:(NSString *)path bytes:(NSData *)bytes;
+ (NSUInteger)timantirecall_downloadCalls;
+ (int32_t)timantirecall_lastDownloadType;
- (instancetype)initWithAIOMsgModel:(QQAIOMsgModel *)model;
- (void)startDownloadImage:(int32_t)type;
@end
@interface TIMAntiRecallReplayPhotoProbe : NSObject
@property(nonatomic) NSUInteger timantirecall_calls;
@property(nonatomic) int32_t timantirecall_subtype;
@property(nonatomic,strong) NSData *timantirecall_bytes;
@property(nonatomic,copy) NSString *timantirecall_path;
@property(nonatomic,strong) OCContact *timantirecall_contact;
@property(nonatomic,strong) id timantirecall_additional;
@property(nonatomic,strong) id timantirecall_conversionGuild;
@property(nonatomic,copy) void(^timantirecall_completion)(int32_t,NSString *);
+ (instancetype)timantirecall_shared;
@end
@interface QQMsgService (TIMAntiRecallPhotoFixture)
- (void)sendPicMsg:(NTAIOContact *)contact sourcePath:(NSString *)path additionalMsg:(id)additional picSubType:(int32_t)subtype callBack:(void(^)(int32_t,NSString *))callback;
@end
