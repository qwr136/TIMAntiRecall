#import "TIMAntiRecallPacket.h"
#import "TIMAntiRecallWalletNativeFixture.h"

@interface OCWalletElement : NSObject
@property(nonatomic) int32_t msgType;
@property(nonatomic) uint64_t grabbedAmount;
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
static NSUInteger timantirecall_openButtonCalls, timantirecall_closeButtonCalls;
static int timantirecall_receiptMode; // 0=model,1=unknown,2=error,3=native success,4=error,5=wrong bill,6=no amount,7=push
static __weak CFT_UIRedGiftDetailBaseViewController *timantirecall_resultController;
// Mirror the exact locked binary's weak forwarding boundary, not a direct target.
@interface WeakProxy : NSObject
@property(nonatomic,weak) id target;
@end
@implementation WeakProxy
- (id)forwardingTargetForSelector:(SEL)selector {(void)selector;return self.target;}
- (BOOL)respondsToSelector:(SEL)selector {return [self.target respondsToSelector:selector];}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {(void)selector;return [NSMethodSignature signatureWithObjCTypes:"v@:"];}
@end
@interface TIMAntiRecallPacketOpenFixture : NSObject
@property(nonatomic,strong) UIView *timantirecall_overlay;
@property(nonatomic,weak) UIViewController *timantirecall_presenter;
@property(nonatomic,strong) OCWalletElement *timantirecall_wallet;
@property(nonatomic,strong) NSArray *timantirecall_proxies;
@property(nonatomic,weak) UIButton *timantirecall_closeButton;
@property(nonatomic,copy) void (^timantirecall_completion)(NSDictionary *,NSError *);
- (void)timantirecall_open:(UIButton *)sender;
- (void)openButtonClick;
- (void)dismissView;
@end
@implementation TIMAntiRecallPacketOpenFixture
- (void)timantirecall_open:(UIButton *)sender {
    (void)sender;timantirecall_openButtonCalls++;
    [self.timantirecall_overlay removeFromSuperview];
    if(self.timantirecall_completion)self.timantirecall_completion(@{},nil);
}
- (void)openButtonClick {
    timantirecall_openButtonCalls++;
    if(timantirecall_receiptMode>=3) {
        [self.timantirecall_overlay removeFromSuperview];
        QQWalletPreGrapHBResultViewController *consumer=[QQWalletPreGrapHBResultViewController new];
        QQWalletGrapHBData *data=[QQWalletGrapHBData new];data.aioData=[QQWalletGrapHBAIOData new];
        data.aioData.listId=self.timantirecall_wallet.billNo;consumer.grapHBData=data;
        NSDictionary *response=@{@"state":timantirecall_receiptMode==4?@6:@0,
            @"recv_object":timantirecall_receiptMode==6?@{}:@{@"amount":@"1"}};
        NSUInteger forwards=timantirecall_nativeResultForwards;
        [consumer handleHBGrapResult:response];
        timantirecall_check(timantirecall_nativeResultForwards==forwards+1 && consumer.grapHBData.grapResultData==response,@"native response hook preserves one consumer and exact dictionary");
        CFT_UIRedGiftDetailBaseViewController *result=[CFT_UIRedGiftDetailBaseViewController new];
        result.listid=timantirecall_receiptMode==5?@"wrong-bill":self.timantirecall_wallet.billNo;
        result.title=@"QQ红包";
        timantirecall_resultController=result;
        if(timantirecall_receiptMode==7)[self.timantirecall_presenter.navigationController pushViewController:result animated:NO];
        else {
            result.modalPresentationStyle=UIModalPresentationFullScreen;
            [self.timantirecall_presenter presentViewController:result animated:NO completion:nil];
        }
        NSError *error=timantirecall_receiptMode==4?[NSError errorWithDomain:@"native-fixture" code:2 userInfo:nil]:nil;
        if(self.timantirecall_completion)self.timantirecall_completion(@{},error);
        return;
    }
    if(timantirecall_receiptMode!=1)self.timantirecall_wallet.grabbedAmount=1;
    // TIM may rebuild the received page after the open action. Replace the
    // close control to require the production code to find it after receipt.
    [self.timantirecall_closeButton removeFromSuperview];
    UIButton *replacement=[UIButton buttonWithType:UIButtonTypeSystem];replacement.frame=CGRectMake(80,300,120,60);
    [replacement setTitle:@"×" forState:UIControlStateNormal];
    [replacement addTarget:self.timantirecall_proxies[1] action:@selector(dismissView) forControlEvents:UIControlEventTouchUpInside];
    [self.timantirecall_overlay addSubview:replacement];self.timantirecall_closeButton=replacement;
    NSError *error=timantirecall_receiptMode==2?[NSError errorWithDomain:@"native-fixture" code:1 userInfo:nil]:nil;
    if(self.timantirecall_completion)self.timantirecall_completion(@{},error);
}
- (void)dismissView {
    timantirecall_closeButtonCalls++;
    [self.timantirecall_overlay removeFromSuperview];
}
@end
static TIMAntiRecallPacketOpenFixture *timantirecall_openFixture;
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
    if(timantirecall_receiptMode==8) {
        timantirecall_receiptMode=0;
        if(completion)completion(nil,[NSError errorWithDomain:@"native-fixture" code:-1001 userInfo:nil]);
        return;
    }
    TIMAntiRecallPacketOpenFixture *fixture=[TIMAntiRecallPacketOpenFixture new];
    fixture.timantirecall_completion=completion;fixture.timantirecall_presenter=controller;
    UIView *overlay=[[UIView alloc] initWithFrame:controller.view.bounds];
    fixture.timantirecall_overlay=overlay;
    UIButton *open=[UIButton buttonWithType:UIButtonTypeSystem];open.frame=CGRectMake(80,160,120,80);
    // Image-only: no title or accessibility label. The recorded native selector
    // plus validated real Wallet receiver must establish this exact open role.
    WeakProxy *openProxy=[WeakProxy new];openProxy.target=fixture;
    WeakProxy *closeProxy=[WeakProxy new];closeProxy.target=fixture;
    fixture.timantirecall_proxies=@[openProxy,closeProxy];
    fixture.timantirecall_wallet=((OCMsgElement *)record.elements.firstObject).walletElement;
    [open addTarget:openProxy action:@selector(openButtonClick) forControlEvents:UIControlEventTouchUpInside];
    UIButton *close=[UIButton buttonWithType:UIButtonTypeSystem];close.frame=CGRectMake(80,300,120,60);
    [close setTitle:@"×" forState:UIControlStateNormal];
    [close addTarget:closeProxy action:@selector(dismissView) forControlEvents:UIControlEventTouchUpInside];
    fixture.timantirecall_closeButton=close;
    timantirecall_check(class_getInstanceMethod(WeakProxy.class,@selector(openButtonClick))==NULL,@"reproduces device proxy encoding-none without a direct implementation");
    [overlay addSubview:open];[overlay addSubview:close];[controller.view addSubview:overlay];
    timantirecall_openFixture=fixture;
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
        timantirecall_check(![timantirecall_settings() timantirecall_autoClaimRedPackets] && ![timantirecall_settings() timantirecall_claimOwnRedPackets],@"claim and own-sent options start off");
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
        timantirecall_stepDelay=1.6;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==1&&timantirecall_walletRecord==privatePacket,@"only fresh supported incoming private packet reaches route");
        timantirecall_check(timantirecall_openButtonCalls==1,@"private native open control dispatched exactly once");
        timantirecall_check(timantirecall_closeButtonCalls==1 && !timantirecall_openFixture.timantirecall_overlay.window,@"private receipt is followed by one native dismiss");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[privatePacket,groupPacket]];
        timantirecall_stepDelay=0.8;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==2&&timantirecall_walletRecord==groupPacket,@"duplicate skips while fresh group routes without opening chat");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:owner error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"diagnostics" enabled:NO owner:owner error:NULL];
        timantirecall_check(timantirecall_openButtonCalls==2,@"group native open control dispatched exactly once");
        timantirecall_check(timantirecall_closeButtonCalls==2 && !timantirecall_openFixture.timantirecall_overlay.window,@"group receipt is followed by one native dismiss");
        timantirecall_forwardedRecords=nil;timantirecall_walletRecord=nil;timantirecall_openFixture=nil;
        [timantirecall_coverage addObjectsFromArray:@[@"packet-monitor",@"packet-open-action",@"packet-proxy-forwarding",@"packet-receipt-close"]];
    });
}
