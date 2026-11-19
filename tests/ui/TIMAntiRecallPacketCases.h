#import "TIMAntiRecallPacket.h"

@interface OCWalletElement : NSObject
@property(nonatomic) int32_t msgType;
@property(nonatomic,copy) NSString *billNo;
@end
@implementation OCWalletElement @end
@interface OCMsgElement : NSObject
@property(nonatomic) int32_t elementType;
@property(nonatomic,strong) OCWalletElement *walletElement;
@end
@implementation OCMsgElement @end

static NSUInteger timantirecall_ingressCalls, timantirecall_walletCalls;
static NSArray *timantirecall_forwardedRecords;
static OCMsgRecord *timantirecall_walletRecord;
@interface NTMsgPushMonitorService : NSObject
+ (void)recvMsgsWithRecords:(NSArray *)records;
@end
@implementation NTMsgPushMonitorService
+ (void)recvMsgsWithRecords:(NSArray *)records {timantirecall_ingressCalls++;timantirecall_forwardedRecords=records;}
@end
@interface QQWalletNTRedPackMsgModel : NSObject
- (instancetype)initWithOCMsgRecord:(OCMsgRecord *)record;
@end
@implementation QQWalletNTRedPackMsgModel
- (instancetype)initWithOCMsgRecord:(OCMsgRecord *)record { (void)record;return [super init]; }
@end
@interface QQWalletRedPacketMsgService : NSObject
+ (void)grabRedPackWithMsgRecord:(OCMsgRecord *)record rootVC:(UIViewController *)controller completion:(void (^)(NSDictionary *, NSError *))completion;
@end
@implementation QQWalletRedPacketMsgService
+ (void)grabRedPackWithMsgRecord:(OCMsgRecord *)record rootVC:(UIViewController *)controller completion:(void (^)(NSDictionary *, NSError *))completion {
    timantirecall_check(NSThread.isMainThread && controller.view.window==timantirecall_window,@"native route receives visible controller on main queue");
    timantirecall_walletRecord=record;timantirecall_walletCalls++;
    completion(@{},nil);
}
@end
@interface NTRedPackRouterService : NSObject
+ (BOOL)isSupportRedPackWithMsgType:(int32_t)type;
+ (void)handleRedPackViewClickWithRootVC:(UIViewController *)controller msgRecord:(OCMsgRecord *)record gesture:(UITapGestureRecognizer *)gesture completion:(void (^)(NSDictionary *, NSError *))completion;
@end
@implementation NTRedPackRouterService
+ (BOOL)isSupportRedPackWithMsgType:(int32_t)type {return type==2 || type==3;}
+ (void)handleRedPackViewClickWithRootVC:(UIViewController *)controller msgRecord:(OCMsgRecord *)record gesture:(UITapGestureRecognizer *)gesture completion:(void (^)(NSDictionary *, NSError *))completion {
    timantirecall_check(!gesture,@"does not synthesize a gesture or a secondary confirmation");
    [QQWalletRedPacketMsgService grabRedPackWithMsgRecord:record rootVC:controller completion:completion];
}
@end
static OCMsgRecord *timantirecall_testPacket(int chat, int64_t seq, int32_t type, NSString *bill) {
    OCMsgRecord *record=timantirecall_record(chat,seq,@"peer_a",7001);
    record.msgType=10;record.isOnlineMsg=YES;record.msgTime=(int64_t)NSDate.date.timeIntervalSince1970;
    OCWalletElement *wallet=[OCWalletElement new];wallet.msgType=type;wallet.billNo=bill;
    OCMsgElement *element=[OCMsgElement new];element.elementType=9;element.walletElement=wallet;
    record.elements=@[element];return record;
}
static void timantirecall_testPacketMonitor(void) {
    __block OCMsgRecord *privatePacket,*groupPacket;
    NSString *owner=@"self_uid";
    timantirecall_step(^{
        QQAccountsManager.GetInstance.currentUid=owner;
        timantirecall_check(timantirecall_installPacketMonitor()&&timantirecall_installPacketMonitor(),@"packet monitor verifies/hook installs once");
        timantirecall_check(![timantirecall_settings() timantirecall_autoClaimRedPackets],@"packet opt-in starts off");
        privatePacket=timantirecall_testPacket(1,8101,2,@"fixture-private");
        groupPacket=timantirecall_testPacket(2,8102,3,@"fixture-group");
        timantirecall_check([timantirecall_settings() timantirecall_setPacketOption:@"diagnostics" enabled:YES owner:owner error:NULL],@"packet diagnostics opt-in persists");
        NSArray *batch=@[privatePacket];[NTMsgPushMonitorService recvMsgsWithRecords:batch];
        timantirecall_check(timantirecall_ingressCalls==1&&timantirecall_forwardedRecords==batch,@"strictly preserves original batch and forwarding count");
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==0,@"diagnostics alone never routes a packet");
        timantirecall_check([timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:owner error:NULL],@"claim requires opt-in");
        OCMsgRecord *old=timantirecall_testPacket(1,8103,2,@"fixture-old");old.msgTime-=3600;
        OCMsgRecord *sent=timantirecall_testPacket(1,8104,2,@"fixture-self");sent.senderUid=owner;
        OCMsgRecord *special=timantirecall_testPacket(2,8105,6,@"fixture-special");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[old,sent,special,privatePacket]];
        timantirecall_stepDelay=1.2;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==1&&timantirecall_walletRecord==privatePacket,@"only fresh supported incoming private packet reaches route");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[privatePacket,groupPacket]];
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==2&&timantirecall_walletRecord==groupPacket,@"duplicate skips while fresh group routes without opening chat");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:owner error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"diagnostics" enabled:NO owner:owner error:NULL];
        timantirecall_forwardedRecords=nil;timantirecall_walletRecord=nil;
        [timantirecall_coverage addObject:@"packet-monitor"];
    });
}
