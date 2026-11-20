// Runtime doubles for the audited native boundaries, not proprietary network code.
static NSUInteger timantirecall_silentPresents,timantirecall_silentLoadings,timantirecall_silentPrepares,timantirecall_silentClaims;
static NSUInteger timantirecall_silentChecks,timantirecall_silentUpdates,timantirecall_silentVerifications;
static BOOL timantirecall_silentHold;
static NSMutableArray<OCMsgRecord *> *timantirecall_silentStarts;
static char timantirecall_silentFixtureDataKey;
static NSDictionary *timantirecall_silentForwardedEnvelope;
static NSDictionary *timantirecall_silentNativeEnvelope(NSString *bill) {
    // Match native grabHBParam: outer metadata plus nested extra_data.
    return @{@"extra_data":@{@"listid":bill,@"channel":@1},@"app_info":@"native-fixture-envelope"};
}
@interface QQWallet : NSObject {
@public
    BOOL tenpayDataHasLoaded;
    id _currentTask;
    id _imageDownloader;
    void (^_tenpayComletionBlock)(void);
    void (^_tenpayCgiCompletionBlock)(void);
    void (^_grabCompletionBlock)(NSDictionary *,NSError *);
    BOOL _isPaying;
}
+ (instancetype)GetInstance;
- (BOOL)isPaying;
- (void)grabHB:(UIViewController *)root params:(NSDictionary *)params completion:(void (^)(NSDictionary *,NSError *))completion;
@end
@interface QQWalletSceneManager : NSObject
+ (void)presentTransparentViewController:(UIViewController *)controller;
@end
@interface QQWalletGrapHBService (TIMAntiRecallSilentFixture)
@property(nonatomic,strong) QQWalletGrapHBData *grapHBData;
+ (BOOL)isGotoNewGrapProcess:(NSDictionary *)params;
+ (BOOL)isNeedGotoPreGrapProcess:(NSDictionary *)params;
- (void)showLoading;
- (BOOL)preGrapHBProcess:(NSDictionary *)params completion:(void (^)(NSDictionary *,NSError *))completion;
- (void)grapHBAfterPreGrapProcess:(NSDictionary *)params isNeedDefaultLoading:(BOOL)loading completion:(void (^)(NSDictionary *,NSError *))completion;
@end
@interface QQWalletPreGrapHBResultViewController (TIMAntiRecallSilentFixture)
- (instancetype)initWithHBData:(QQWalletGrapHBData *)data;
- (void)onOpenButtonClick:(id)view;
@end
@implementation QQWallet
+ (instancetype)GetInstance {static QQWallet *instance;static dispatch_once_t once;dispatch_once(&once,^{instance=[self new];});return instance;}
- (BOOL)isPaying {return _isPaying;}
- (void)grabHB:(UIViewController *)root params:(NSDictionary *)params completion:(void (^)(NSDictionary *,NSError *))completion {
    (void)root;
    timantirecall_check(!self->_grabCompletionBlock && !self->_isPaying,@"native original entry never overwrites a lower wallet operation");
    timantirecall_silentForwardedEnvelope=params;
    timantirecall_check([params[@"extra_data"] isKindOfClass:NSDictionary.class] && params[@"listid"]==nil,@"original Wallet receives unchanged native nested envelope, not flattened parameters");
    [QQWalletGrapHBService.shareInstance preGrapHBProcess:params completion:completion];
}
@end
@implementation QQWalletSceneManager
+ (void)presentTransparentViewController:(UIViewController *)controller {
    timantirecall_silentPresents++;
    controller.modalPresentationStyle=UIModalPresentationOverFullScreen;
    UIViewController *host=timantirecall_window.rootViewController;
    if(host.presentedViewController)host=host.presentedViewController;
    [host presentViewController:controller animated:NO completion:nil];
}
@end
static void timantirecall_silentRelease(NSDictionary *result,NSError *error) {
    QQWalletGrapHBService *native=QQWalletGrapHBService.shareInstance;
    QQWallet *wallet=QQWallet.GetInstance;
    timantirecall_silentUpdates++;
    void (^claim)(NSDictionary *,NSError *)=native.grapHBCallback;
    if(claim)claim(result,error);
    native.grapHBCallback=nil;
    void (^pre)(NSDictionary *,NSError *)=native.preGrapHBCallback;
    if(pre)pre(result,error);
    native.preGrapHBCallback=nil;
    wallet->_grabCompletionBlock=nil;
}
@implementation QQWalletGrapHBService (TIMAntiRecallSilentFixture)
- (QQWalletGrapHBData *)grapHBData {return objc_getAssociatedObject(self,&timantirecall_silentFixtureDataKey);}
- (void)setGrapHBData:(QQWalletGrapHBData *)data {objc_setAssociatedObject(self,&timantirecall_silentFixtureDataKey,data,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
+ (BOOL)isGotoNewGrapProcess:(NSDictionary *)params {timantirecall_silentChecks++;return ![params[@"extra_data"][@"listid"] hasSuffix:@"unsupported"];}
+ (BOOL)isNeedGotoPreGrapProcess:(NSDictionary *)params {timantirecall_silentChecks++;return ![params[@"extra_data"][@"listid"] hasSuffix:@"nopre"];}
- (void)showLoading {timantirecall_silentLoadings++;}
- (BOOL)preGrapHBProcess:(NSDictionary *)params completion:(void (^)(NSDictionary *,NSError *))completion {
    timantirecall_check(!self.preGrapHBCallback && !self.grapHBCallback,@"native pre-open retains its original callbacks and does not overlap");
    timantirecall_silentPrepares++;self.preGrapHBCallback=completion;
    QQWalletGrapHBData *data=[QQWalletGrapHBData new];data.aioData=[QQWalletGrapHBAIOData new];data.aioData.listId=params[@"extra_data"][@"listid"];self.grapHBData=data;
    [self showLoading];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        if([data.aioData.listId hasSuffix:@"verify"]) {
            timantirecall_silentVerifications++;
            void (^callback)(NSDictionary *,NSError *)=self.preGrapHBCallback;
            if(callback)callback(@{@"state":@5},nil);
            self.preGrapHBCallback=nil;return;
        }
        data.grapResultData=@{@"state":@16,@"pre_grap_token":@"native-test-token"};
        QQWalletPreGrapHBResultViewController *popup=[[QQWalletPreGrapHBResultViewController alloc] initWithHBData:data];
        timantirecall_fixturePopup=popup;
        [QQWalletSceneManager presentTransparentViewController:popup];
    });
    return YES;
}
- (void)grapHBAfterPreGrapProcess:(NSDictionary *)params isNeedDefaultLoading:(BOOL)loading completion:(void (^)(NSDictionary *,NSError *))completion {
    timantirecall_check(!loading && [params[@"pre_grap_token"] isEqual:@"native-test-token"],@"native claim consumes its actual pre-open token without changing loading flags");
    timantirecall_check(!self.grapHBCallback && QQWallet.GetInstance->_grabCompletionBlock==nil,@"original claim slot remains free until the native continuation");
    timantirecall_silentClaims++;self.grapHBCallback=completion;QQWallet.GetInstance->_grabCompletionBlock=completion;
    if(timantirecall_silentHold)return;
    NSString *bill=self.grapHBData.aioData.listId;
    NSDictionary *response=[bill hasSuffix:@"unknown"]?@{@"state":@9}:
        ([bill hasSuffix:@"error"]?@{@"state":@6}:@{@"state":@0,@"recv_object":@{@"amount":@123},@"send_object":@{@"amount":@9900}});
    NSError *error=[bill hasSuffix:@"error"]?[NSError errorWithDomain:@"native-fixture" code:6 userInfo:nil]:nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,75*NSEC_PER_MSEC),dispatch_get_main_queue(),^{timantirecall_silentRelease(response,error);});
}
@end
@implementation QQWalletPreGrapHBResultViewController (TIMAntiRecallSilentFixture)
- (instancetype)initWithHBData:(QQWalletGrapHBData *)data {self=[self init];if(self)self.grapHBData=data;return self;}
- (void)onOpenButtonClick:(id)view {
    timantirecall_check(view==self.grapHBView && self.grapHBView.grapHBData==self.grapHBData,@"native original action receives its exact sender view and model");
    NSMutableDictionary *params=[@{@"listid":self.grapHBData.aioData.listId} mutableCopy];
    params[@"pre_grap_token"]=self.grapHBData.grapResultData[@"pre_grap_token"];
    __weak typeof(self) weakSelf=self;
    [QQWalletGrapHBService.shareInstance grapHBAfterPreGrapProcess:params isNeedDefaultLoading:NO completion:^(NSDictionary *result,__unused NSError *error){
        [weakSelf handleHBGrapResult:result];
    }];
}
@end
