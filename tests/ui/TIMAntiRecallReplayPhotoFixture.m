#import "TIMAntiRecallReplayPhotoFixture.h"
@implementation TIMAntiRecallReceivedPic
- (NSString *)fetchOriginalImgPathWithCreateFolder:(BOOL)create {
    self.timantirecall_cacheCalls++;self.timantirecall_createRequested|=create;
    return self.timantirecall_originalPath;
}
@end
@implementation TIMAntiRecallReceivedPicWrongABI
- (NSString *)fetchOriginalImgPathWithCreateFolder:(int64_t)create {
    (void)create;self.timantirecall_wrongCalls++;return @"/must-not-be-called";
}
@end
@implementation NTAIOContact
- (OCContact *)convertToOCContact {
    OCContact *contact=[OCContact new];contact.chatType=(int32_t)self.chatType;contact.guildId=@"";
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
