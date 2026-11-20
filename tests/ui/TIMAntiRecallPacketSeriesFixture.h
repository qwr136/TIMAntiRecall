// Exact module-facing signatures; test objects only, no Wallet network code.
@interface QQWalletGrapHBService : NSObject
@property(nonatomic,copy) void (^preGrapHBCallback)(NSDictionary *,NSError *);
@property(nonatomic,copy) void (^grapHBCallback)(NSDictionary *,NSError *);
+ (instancetype)shareInstance;
@end
@implementation QQWalletGrapHBService
+ (instancetype)shareInstance {static QQWalletGrapHBService *instance;static dispatch_once_t once;dispatch_once(&once,^{instance=[self new];});return instance;}
@end
@interface QQWalletGrapHBAIOData : NSObject
@property(nonatomic,copy) NSString *listId;
@end
@implementation QQWalletGrapHBAIOData @end
@interface QQWalletGrapHBData : NSObject
@property(nonatomic,strong) QQWalletGrapHBAIOData *aioData;
@property(nonatomic,copy) NSDictionary *grapResultData;
@end
@implementation QQWalletGrapHBData @end
static NSUInteger timantirecall_detailsShown,timantirecall_nativePopupCloses,timantirecall_nativePopupOpens;
void (^const timantirecall_fixtureDetails)(void)=^{timantirecall_detailsShown++;};
@class QQWalletPreGrapHBResultViewController;
@interface QQWalletPreOpenHBView : UIView
@property(nonatomic,weak) QQWalletPreGrapHBResultViewController *controller;
@property(nonatomic,strong) QQWalletGrapHBData *grapHBData;
@property(nonatomic,copy) void (^grapHBAnimationBlock)(BOOL);
@property(nonatomic,strong) NSArray *timantirecall_targets;
- (void)openButtonClick;
- (void)dismissView;
@end
@interface QQWalletPreGrapHBResultViewController : UIViewController
@property(nonatomic,strong) QQWalletPreOpenHBView *grapHBView;
@property(nonatomic,strong) QQWalletGrapHBData *grapHBData;
@property(nonatomic,copy) void (^timantirecall_callback)(NSDictionary *,NSError *);
@property(nonatomic) NSUInteger timantirecall_variant;
- (void)handleHBGrapResult:(NSDictionary *)result;
@end
static __weak QQWalletPreGrapHBResultViewController *timantirecall_fixturePopup;
static __weak UIViewController *timantirecall_fixtureHost;
static NSMutableArray<OCMsgRecord *> *timantirecall_seriesStarts;
static BOOL timantirecall_seriesEnabled;
@implementation QQWalletPreGrapHBResultViewController
- (void)loadView {
    UIView *root=[[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];root.backgroundColor=UIColor.systemBackgroundColor;
    QQWalletPreOpenHBView *sheet=[[QQWalletPreOpenHBView alloc] initWithFrame:root.bounds];
    sheet.autoresizingMask=UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;sheet.controller=self;sheet.grapHBData=self.grapHBData;
    UIButton *open=[UIButton buttonWithType:UIButtonTypeSystem];open.frame=CGRectMake(80,160,120,70);
    UIButton *close=[UIButton buttonWithType:UIButtonTypeSystem];close.frame=CGRectMake(80,265,120,55);
    WeakProxy *target=[WeakProxy new];target.target=sheet;sheet.timantirecall_targets=@[target];
    [open addTarget:target action:@selector(openButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [close addTarget:target action:@selector(dismissView) forControlEvents:UIControlEventTouchUpInside];
    [sheet addSubview:open];[sheet addSubview:close];[root addSubview:sheet];self.grapHBView=sheet;self.view=root;
}
- (void)handleHBGrapResult:(NSDictionary *)result {
    self.grapHBData.grapResultData=result;
    if([result[@"state"] isEqual:@0] && [result[@"recv_object"] isKindOfClass:NSDictionary.class]) {
        __weak typeof(self) weakSelf=self;
        self.grapHBView.grapHBAnimationBlock=^(BOOL completed){
            QQWalletPreGrapHBResultViewController *live=weakSelf;
            if(completed && live)[live dismissViewControllerAnimated:NO completion:timantirecall_fixtureDetails];
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,220*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            void (^finish)(BOOL)=weakSelf.grapHBView.grapHBAnimationBlock;
            if(finish)finish(YES);
        });
    }
}
@end
@implementation QQWalletPreOpenHBView
- (void)openButtonClick {
    timantirecall_nativePopupOpens++;
    QQWalletGrapHBService *wallet=QQWalletGrapHBService.shareInstance;
    timantirecall_check(!wallet.grapHBCallback,@"native claim starts only with the claim slot free");
    QQWalletPreGrapHBResultViewController *popup=self.controller;
    __weak QQWalletPreGrapHBResultViewController *weakPopup=popup;
    wallet.grapHBCallback=^(NSDictionary *response,NSError *error){
        QQWalletPreGrapHBResultViewController *live=weakPopup;
        if(response)[live handleHBGrapResult:response];
        if(live.timantirecall_callback)live.timantirecall_callback(nil,error);
    };
    if(popup.timantirecall_variant!=1) {
        NSDictionary *result=popup.timantirecall_variant==2?@{@"state":@6}:@{@"state":@0,@"recv_object":@{@"amount":@123},@"send_object":@{@"amount":@9900}};
        NSError *error=popup.timantirecall_variant==2?[NSError errorWithDomain:@"native-fixture" code:6 userInfo:nil]:nil;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,75*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            void (^callback)(NSDictionary *,NSError *)=wallet.grapHBCallback;
            if(callback)callback(result,error);
            wallet.grapHBCallback=nil;wallet.preGrapHBCallback=nil;
        });
    }
}
- (void)dismissView {
    timantirecall_check(!QQWalletGrapHBService.shareInstance.grapHBCallback && !QQWalletGrapHBService.shareInstance.preGrapHBCallback,
                      @"retire an ordinary popup only after native callback slots release");
    timantirecall_nativePopupCloses++;
    [self.controller dismissViewControllerAnimated:NO completion:nil];
}
@end
