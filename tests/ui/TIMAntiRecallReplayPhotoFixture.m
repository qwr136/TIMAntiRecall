#import "TIMAntiRecallReplayPhotoFixture.h"
@implementation TIMAntiRecallReceivedPic
- (NSString *)fetchOriginalImgPathWithCreateFolder:(BOOL)create {
    self.timantirecall_cacheCalls++;self.timantirecall_createRequested|=create;
    return self.timantirecall_originalPath;
}
@end
@implementation NTRecordConverter (TIMAntiRecallNativePhoto)
+ (QQAIOMsgModel *)recordConvertAIOMsgModel:(OCMsgRecord *)record {
    QQMessageModel *message=[self recordConvertMessageModel:record];if(!message)return nil;
    QQAIOMsgModel *aio=[QQAIOMsgModel new];aio.msgModel=message;return aio;
}
@end
static NSString *timantirecall_fakeOriginalPath;static NSData *timantirecall_fakeOriginalBytes;
static NSUInteger timantirecall_fakeOriginalDownloadCalls;static int32_t timantirecall_fakeOriginalDownloadType;
@implementation QQRichMediaPhotoBrowserChatImageAgent
+ (void)timantirecall_configureOriginalDownloadPath:(NSString *)path bytes:(NSData *)bytes {
    timantirecall_fakeOriginalPath=[path copy];timantirecall_fakeOriginalBytes=[bytes copy];
    timantirecall_fakeOriginalDownloadCalls=0;timantirecall_fakeOriginalDownloadType=0;
}
+ (NSUInteger)timantirecall_downloadCalls {return timantirecall_fakeOriginalDownloadCalls;}
+ (int32_t)timantirecall_lastDownloadType {return timantirecall_fakeOriginalDownloadType;}
- (instancetype)initWithAIOMsgModel:(QQAIOMsgModel *)model {(void)model;return [super init];}
- (void)startDownloadImage:(int32_t)type {
    timantirecall_fakeOriginalDownloadCalls++;timantirecall_fakeOriginalDownloadType=type;
    if(type!=2)return;
    NSString *path=[timantirecall_fakeOriginalPath copy];NSData *bytes=[timantirecall_fakeOriginalBytes copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.15*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if([bytes writeToFile:path options:NSDataWritingAtomic error:NULL])self.originalImagePath=path;
    });
}
@end
@implementation TIMAntiRecallReceivedPicWrongABI
- (NSString *)fetchOriginalImgPathWithCreateFolder:(int64_t)create {
    (void)create;self.timantirecall_wrongCalls++;return @"/must-not-be-called";
}
@end
@implementation NTAIOContact
- (OCContact *)convertToOCContact {
    OCContact *contact=[OCContact new];contact.chatType=(int32_t)self.chatType;
    // Locked native converter returns nil guildId for ordinary chats; record.contact bridges it to @"".
    contact.guildId=TIMAntiRecallReplayPhotoProbe.timantirecall_shared.timantirecall_conversionGuild;
    contact.peerUid=self.chatType==2?self.groupCode:([self.uin isEqual:@"12345"]?@"photo_peer":@"different_peer");
    return contact;
}
@end
@implementation TIMAntiRecallReplayPhotoProbe
+ (instancetype)timantirecall_shared {static id probe;static dispatch_once_t once;dispatch_once(&once,^{probe=[self new];});return probe;}
@end
@implementation QQMsgService (TIMAntiRecallPhotoFixture)
- (void)sendPicMsg:(NTAIOContact *)contact sourcePath:(NSString *)path additionalMsg:(id)additional picSubType:(int32_t)subtype callBack:(void(^)(int32_t,NSString *))callback {
    TIMAntiRecallReplayPhotoProbe *probe=TIMAntiRecallReplayPhotoProbe.timantirecall_shared;
    probe.timantirecall_calls++;probe.timantirecall_subtype=subtype;probe.timantirecall_path=path;
    // Like the native local-file branch, consume bytes synchronously then retain
    // the data for asynchronous upload; never retain or mutate the original record.
    probe.timantirecall_bytes=[NSData dataWithContentsOfFile:path];
    probe.timantirecall_contact=[contact convertToOCContact];probe.timantirecall_additional=additional;
    probe.timantirecall_completion=callback;self.timantirecall_sendCalls++;
    self.timantirecall_lastContact=probe.timantirecall_contact;
}
@end
