#import "TIMAntiRecallPacket.h"
#import "TIMAntiRecallPacketOpen.h"
#import "TIMAntiRecallPacketWallet.h"
#if defined(TIMANTIRECALL_NATIVE_TEST)
BOOL timantirecall_installPacketMonitor(void) { return NO; } // macOS has no UIKit.
#else
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallTrace.h"
#import "TIMAntiRecallMarks.h"
#import <UIKit/UIKit.h>
#include <stdatomic.h>
#include <stdlib.h>

static _Atomic(IMP) timantirecall_packetOriginal;
static atomic_uint timantirecall_packetEpoch;
static atomic_uint timantirecall_packetPending;
static NSMutableDictionary<NSString *, NSNumber *> *timantirecall_packetAttempts; // main queue only
// Queue stores short-lived record references, never writes message data.
@interface TIMAntiRecallPacketItem : NSObject
@property(nonatomic,strong) id timantirecall_record,timantirecall_wallet;
@property(nonatomic,copy) NSString *timantirecall_owner,*timantirecall_bill;
@property(nonatomic,copy) NSDictionary *timantirecall_identity;
@property(nonatomic,copy) NSString *timantirecall_waitReason;
@property(nonatomic) unsigned timantirecall_epoch;
@property(nonatomic) NSTimeInterval timantirecall_deadline;
@property(nonatomic) NSUInteger timantirecall_number;
@property(nonatomic) BOOL timantirecall_own;
@end
@implementation TIMAntiRecallPacketItem @end
static NSMutableArray<TIMAntiRecallPacketItem *> *timantirecall_packetQueue;
static BOOL timantirecall_packetPumpScheduled;
static NSUInteger timantirecall_packetNumber;
static void timantirecall_packetPump(void);
static NSUInteger timantirecall_packetSerial;

typedef void (^TIMAntiRecallPacketCompletion)(NSDictionary *, NSError *);
typedef void (*TIMAntiRecallPacketIngress)(id, SEL, NSArray *);
typedef void (*TIMAntiRecallPacketRoute)(id, SEL, UIViewController *, id, UITapGestureRecognizer *, TIMAntiRecallPacketCompletion);

static Method timantirecall_packetOwnClassMethod(Class cls, SEL selector) {
    if (!cls) return NULL;
    unsigned count = 0;
    Method *methods = class_copyMethodList(object_getClass(cls), &count), match = NULL;
    for (unsigned i = 0; i < count; i++)
        if (method_getName(methods[i]) == selector) { match = methods[i]; break; }
    free(methods);
    return match;
}
static IMP timantirecall_packetGetter(id object, SEL getter, const char *result) {
    const char *args[] = {"@", ":"};
    Method method = object ? class_getInstanceMethod(object_getClass(object), getter) : NULL;
    return timantirecall_methodTypes(method, result, 2, args) ? method_getImplementation(method) : NULL;
}
static id timantirecall_packetObject(id object, SEL getter) {
    IMP imp = timantirecall_packetGetter(object, getter, "@");
    return imp ? ((id (*)(id, SEL))imp)(object, getter) : nil;
}
static BOOL timantirecall_packetInt(id object, SEL getter, int32_t *out) {
    IMP imp = timantirecall_packetGetter(object, getter, "i");
    if (!imp) return NO;
    *out = ((int32_t (*)(id, SEL))imp)(object, getter);
    return YES;
}
static BOOL timantirecall_packetFlag(id record, SEL getter, BOOL required) {
    IMP imp = timantirecall_packetGetter(record, getter, "B");
    return imp && ((BOOL (*)(id, SEL))imp)(record, getter) == required;
}

// Epoch is odd only during an active foreground interval. The main queue owns
// UIKit checks; a delivery enqueued before even a brief backgrounding is stale.
static void timantirecall_packetSetActive(BOOL active) {
    unsigned epoch = atomic_load(&timantirecall_packetEpoch);
    if ((BOOL)(epoch & 1) != active) atomic_store(&timantirecall_packetEpoch, epoch + 1);
}
static UIViewController *timantirecall_packetPresenter(void) {
    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *window = nil;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (!candidate.isKeyWindow || candidate.hidden || candidate.windowLevel != UIWindowLevelNormal) continue;
            if (window) return nil;
            window = candidate;
        }
    }
    if (!window && !app.connectedScenes.count && [app.delegate respondsToSelector:@selector(window)]) window = app.delegate.window;
    if (!window || window.hidden || !window.isKeyWindow || window.windowLevel != UIWindowLevelNormal) return nil;
    UIViewController *controller = window.rootViewController;
    for(unsigned depth=0;controller && depth<16;depth++) {
        if(controller.isBeingDismissed || controller.isBeingPresented || controller.transitionCoordinator)return nil;
        if(controller.presentedViewController) {controller=controller.presentedViewController;continue;}
        if([controller isKindOfClass:UINavigationController.class]) {controller=((UINavigationController *)controller).topViewController;continue;}
        if([controller isKindOfClass:UITabBarController.class]) {controller=((UITabBarController *)controller).selectedViewController;continue;}
        if([controller isKindOfClass:UISplitViewController.class]) {controller=((UISplitViewController *)controller).viewControllers.lastObject;continue;}
        if([controller isKindOfClass:UIAlertController.class])return nil;
        // Never layer a new open flow on a Wallet dialog or a payment/verify controller.
        for(NSString *name in @[@"QQWalletBaseDialogViewController",@"QQWalletPreGrapHBResultViewController",@"CFT_UIRedGiftDetailBaseViewController",@"CFT_UIHttpViewController",@"QQWalletBaseViewController"]) {
            Class cls=NSClassFromString(name);if(cls && [controller isKindOfClass:cls])return nil;
        }
        UIView *view=controller.viewIfLoaded;
        return view.window==window && !view.hidden && view.alpha>=0.05 ? controller:nil;
    }
    return nil;
}
static BOOL timantirecall_packetStillActive(NSString *owner, unsigned epoch) {
    return epoch == atomic_load(&timantirecall_packetEpoch) && [owner isEqual:timantirecall_currentAccount()] &&
           UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
}
static BOOL timantirecall_packetReserve(NSString *owner, NSString *bill, NSTimeInterval now) {
    if (![bill isKindOfClass:NSString.class] || !bill.length || bill.length > 128) return NO;
    NSString *key = [NSString stringWithFormat:@"%@/%@", owner, bill];
    if (!timantirecall_packetAttempts) timantirecall_packetAttempts = [NSMutableDictionary dictionary];
    for (NSString *old in timantirecall_packetAttempts.allKeys)
        if (now - timantirecall_packetAttempts[old].doubleValue > 120) [timantirecall_packetAttempts removeObjectForKey:old];
    if (timantirecall_packetAttempts.count >= 512 || timantirecall_packetAttempts[key]) return NO;
    timantirecall_packetAttempts[key] = @(now);
    return YES;
}

static Method timantirecall_packetRoute(Class router, SEL handle) {
    Method route = timantirecall_packetOwnClassMethod(router, handle);
    const char *routeTypes[] = {"@", ":", "@", "@", "@", "@?"};
    Class service = objc_getClass("QQWalletRedPacketMsgService");
    Method entry = class_getClassMethod(service, sel_registerName("grabRedPackWithMsgRecord:rootVC:completion:"));
    const char *entryTypes[] = {"@", ":", "@", "@", "@?"};
    Class model = objc_getClass("QQWalletNTRedPackMsgModel");
    const char *initTypes[] = {"@", ":", "@"};
    if (!timantirecall_methodTypes(route, "v", 6, routeTypes) ||
        !timantirecall_methodTypes(entry, "v", 5, entryTypes) ||
        !timantirecall_methodTypes(class_getInstanceMethod(model, sel_registerName("initWithOCMsgRecord:")), "@", 3, initTypes)) return NULL;
    return route;
}
static BOOL timantirecall_packetItemValid(TIMAntiRecallPacketItem *item) {
    return item && timantirecall_packetStillActive(item.timantirecall_owner,item.timantirecall_epoch) &&
           [timantirecall_settings() timantirecall_autoClaimRedPackets] &&
           (!item.timantirecall_own || [timantirecall_settings() timantirecall_claimOwnRedPackets]);
}
static BOOL timantirecall_packetAttempt(TIMAntiRecallPacketItem *item,UIViewController *presenter) {
    Class router=objc_getClass("NTRedPackRouterService"),service=objc_getClass("QQWalletRedPacketMsgService");
    SEL handle=sel_registerName("handleRedPackViewClickWithRootVC:msgRecord:gesture:completion:");
    Method route=timantirecall_packetRoute(router,handle);
    if(!route || !presenter || !timantirecall_packetItemValid(item))return NO;
    id wallet=item.timantirecall_wallet;
    int32_t type=0;SEL support=sel_registerName("isSupportRedPackWithMsgType:");
    Method supported=timantirecall_packetOwnClassMethod(router,support);
    const char *supportTypes[]={"@",":","i"};
    if(!timantirecall_packetInt(wallet,sel_registerName("msgType"),&type) || (type!=2 && type!=3) ||
       !timantirecall_methodTypes(supported,"B",3,supportTypes) ||
       !((BOOL(*)(id,SEL,int32_t))method_getImplementation(supported))(router,support,type)) {
        timantirecall_traceEvent(@"redpack-type-skipped");return NO;
    }
    if(!timantirecall_packetReserve(item.timantirecall_owner,item.timantirecall_bill,NSProcessInfo.processInfo.systemUptime))return NO;
    NSUInteger serial=++timantirecall_packetSerial;
    SEL amountSelector=sel_registerName("grabbedAmount");
    IMP initialGetter=timantirecall_packetGetter(wallet,amountSelector,"Q");
    uint64_t initialAmount=initialGetter?((uint64_t(*)(id,SEL))initialGetter)(wallet,amountSelector):UINT64_MAX;
    __block BOOL callbackSeen=NO,nativeFailure=NO;
    TIMAntiRecallPacketCompletion completion=^(NSDictionary *result,NSError *error) {
        (void)result;BOOL failed=error!=nil;
        // The original invokes this block before clearing its shared slots.
        dispatch_async(dispatch_get_main_queue(),^{
            if(serial!=timantirecall_packetSerial)return;
            callbackSeen=YES;nativeFailure=nativeFailure || failed;
            timantirecall_traceEvent(failed?@"redpack-native-route-error":@"redpack-native-route-callback");
            timantirecall_packetPump();
        });
    };
    if(!timantirecall_installPacketFinish(service))timantirecall_traceEvent(@"redpack-detail-guard-unavailable");
    // Capture preferences/account for this route without keeping its full queued record.
    NSString *owner=item.timantirecall_owner;unsigned epoch=item.timantirecall_epoch;BOOL own=item.timantirecall_own;
    if(!timantirecall_beginPacketOpenForBill(presenter,service,item.timantirecall_bill,^BOOL(void){
        return timantirecall_packetStillActive(owner,epoch) && [timantirecall_settings() timantirecall_autoClaimRedPackets] &&
               (!own || [timantirecall_settings() timantirecall_claimOwnRedPackets]);
    },^BOOL(void){
        IMP getter=timantirecall_packetGetter(wallet,amountSelector,"Q");
        return !nativeFailure && initialAmount==0 && getter && ((uint64_t(*)(id,SEL))getter)(wallet,amountSelector)>0;
    },^BOOL(void){return callbackSeen;},^BOOL(void){return nativeFailure;}))return NO;
    timantirecall_traceEvent(@"redpack-native-route-attempted");
    ((TIMAntiRecallPacketRoute)method_getImplementation(route))(router,handle,presenter,item.timantirecall_record,nil,completion);
    return YES;
}
static void timantirecall_packetQueueEvent(TIMAntiRecallPacketItem *item,NSString *event) {
    timantirecall_traceEvent([NSString stringWithFormat:@"queue%lu-%@",(unsigned long)item.timantirecall_number,event]);
}
static void timantirecall_packetRetryPump(void) {
    if(timantirecall_packetPumpScheduled || !timantirecall_packetQueue.count)return;
    timantirecall_packetPumpScheduled=YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        timantirecall_packetPumpScheduled=NO;timantirecall_packetPump();
    });
}
static void timantirecall_packetPump(void) {
    @try {
        while(timantirecall_packetQueue.count) {
            TIMAntiRecallPacketItem *item=timantirecall_packetQueue.firstObject;
            NSString *reason=nil;
            if(!timantirecall_packetItemValid(item))reason=@"cancelled-context";
            else if(NSProcessInfo.processInfo.systemUptime>=item.timantirecall_deadline)reason=@"expired";
            else if(![timantirecall_recordIdentity(item.timantirecall_record,item.timantirecall_owner) isEqual:item.timantirecall_identity] ||
                    ![timantirecall_packetObject(item.timantirecall_wallet,sel_registerName("billNo")) isEqual:item.timantirecall_bill])reason=@"identity-changed";
            if(reason) {
                [timantirecall_packetQueue removeObjectAtIndex:0];timantirecall_packetQueueEvent(item,reason);continue;
            }
            Class service=objc_getClass("QQWalletRedPacketMsgService");
            if(!timantirecall_walletCanAcceptPacket(service))reason=@"waiting-wallet";
            else {
                timantirecall_settlePacketUIForNext();
                if(timantirecall_hasPendingPacketUI())reason=@"waiting-ui";
            }
            UIViewController *presenter=reason?nil:timantirecall_packetPresenter();
            if(!presenter && !reason)reason=@"waiting-presenter";
            if(reason) {
                if(![reason isEqual:item.timantirecall_waitReason]) {item.timantirecall_waitReason=reason;timantirecall_packetQueueEvent(item,reason);}
                timantirecall_packetRetryPump();return;
            }
            [timantirecall_packetQueue removeObjectAtIndex:0];
            BOOL started=timantirecall_packetAttempt(item,presenter);
            timantirecall_packetQueueEvent(item,started?@"started":@"rejected");
            if(started) {timantirecall_packetRetryPump();return;}
        }
    } @catch(__unused NSException *exception) {
        timantirecall_traceEvent(@"redpack-queue-pump-aborted");timantirecall_packetRetryPump();
    }
}
static BOOL timantirecall_packetEnqueue(id record,id wallet,NSDictionary *identity,NSString *owner,unsigned epoch,BOOL own,NSTimeInterval age) {
    NSString *bill=timantirecall_packetObject(wallet,sel_registerName("billNo"));
    if(![bill isKindOfClass:NSString.class] || !bill.length || bill.length>128 || timantirecall_packetQueue.count>=32)return NO;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    NSNumber *previous=timantirecall_packetAttempts[[NSString stringWithFormat:@"%@/%@",owner,bill]];
    if(previous && now-previous.doubleValue<=120)return NO;
    for(TIMAntiRecallPacketItem *queued in timantirecall_packetQueue)
        if([queued.timantirecall_owner isEqual:owner] && [queued.timantirecall_bill isEqual:bill])return NO;
    if(!timantirecall_packetQueue)timantirecall_packetQueue=[NSMutableArray array];
    TIMAntiRecallPacketItem *item=[TIMAntiRecallPacketItem new];
    item.timantirecall_record=record;item.timantirecall_wallet=wallet;item.timantirecall_identity=identity;
    item.timantirecall_owner=owner;item.timantirecall_bill=bill;item.timantirecall_epoch=epoch;item.timantirecall_own=own;
    item.timantirecall_deadline=now+30-MAX(0,age);item.timantirecall_number=++timantirecall_packetNumber;
    [timantirecall_packetQueue addObject:item];timantirecall_packetQueueEvent(item,@"enqueued");return YES;
}

static BOOL timantirecall_packetObserve(id record, NSString *owner, unsigned epoch, BOOL autoClaim, BOOL claimOwn, BOOL diagnose) {
    Class recordClass = objc_getClass("OCMsgRecord");
    Class elementClass = objc_getClass("OCMsgElement"), walletClass = objc_getClass("OCWalletElement");
    if (!recordClass || !elementClass || !walletClass || ![record isKindOfClass:recordClass]) return NO;
    int32_t chat = 0, kind = 0;
    if (!timantirecall_packetInt(record, sel_registerName("chatType"), &chat) || (chat != 1 && chat != 2) ||
        !timantirecall_packetInt(record, sel_registerName("msgType"), &kind) || kind != 10) return NO;
    NSArray *elements = timantirecall_packetObject(record, sel_registerName("elements"));
    if (![elements isKindOfClass:NSArray.class] || elements.count > 32) return NO;
    id wallet = nil;
    for (id element in elements) {
        int32_t type = 0;
        if (![element isKindOfClass:elementClass] || !timantirecall_packetInt(element, sel_registerName("elementType"), &type) || type != 9) continue;
        id candidate = timantirecall_packetObject(element, sel_registerName("walletElement"));
        if (wallet || ![candidate isKindOfClass:walletClass]) return NO;
        wallet = candidate;
    }
    if (!wallet) return NO;
    NSDictionary *identity = timantirecall_recordIdentity(record, owner);
    if (!identity) return NO;
    BOOL own = [identity[@"author"] isEqual:owner];
    if (own && !claimOwn) {if (diagnose) timantirecall_traceEvent(@"redpack-own-sender-skipped");return NO;}
    if (diagnose) timantirecall_traceEvent(own ? @"redpack-own-sender-enabled" : (chat == 1 ? @"redpack-private-observed" : @"redpack-group-observed"));
    NSTimeInterval age = NSDate.date.timeIntervalSince1970 - [identity[@"time"] doubleValue];
    BOOL fresh = age >= -4 && age <= 30 &&
        timantirecall_packetFlag(record, sel_registerName("isOnlineMsg"), YES) &&
        timantirecall_packetFlag(record, sel_registerName("isImportMsg"), NO);
    if (!fresh) {
        if (diagnose) timantirecall_traceEvent(@"redpack-not-confirmed-live");
        return NO;
    }
    if(!autoClaim) {
        Class router=objc_getClass("NTRedPackRouterService");
        Method route=timantirecall_packetRoute(router,sel_registerName("handleRedPackViewClickWithRootVC:msgRecord:gesture:completion:"));
        if(diagnose)timantirecall_traceEvent(route?@"redpack-route-available":@"redpack-route-unavailable");
        return NO;
    }
    return timantirecall_packetEnqueue(record,wallet,identity,owner,epoch,own,age);
}

static void timantirecall_packetReceive(id target, SEL selector, NSArray *records) {
    TIMAntiRecallPacketIngress original = (TIMAntiRecallPacketIngress)atomic_load(&timantirecall_packetOriginal);
    unsigned epoch = atomic_load(&timantirecall_packetEpoch);
    NSString *owner = nil;
    BOOL autoClaim = NO, claimOwn = NO, diagnose = NO;
    if (epoch & 1) {
        @try {
            owner = timantirecall_currentAccount();
            autoClaim = owner && [timantirecall_settings() timantirecall_autoClaimRedPackets];
            claimOwn = autoClaim && [timantirecall_settings() timantirecall_claimOwnRedPackets];
            diagnose = owner && [timantirecall_settings() timantirecall_packetDiagnostics];
        } @catch (__unused NSException *exception) {
            autoClaim = diagnose = NO;
        }
    }
    original(target, selector, records);
    if (!autoClaim && !diagnose) return;
    if (atomic_fetch_add(&timantirecall_packetPending, 1) >= 4) {
        atomic_fetch_sub(&timantirecall_packetPending, 1);
        return;
    }
    NSArray *snapshot = nil;
    @try {
        if ([records isKindOfClass:NSArray.class] && records.count)
            snapshot = [records subarrayWithRange:NSMakeRange(0, MIN(records.count, (NSUInteger)64))];
    } @catch (__unused NSException *exception) {}
    if (!snapshot) {
        atomic_fetch_sub(&timantirecall_packetPending, 1);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!timantirecall_packetStillActive(owner, epoch)) return;
            BOOL claim = autoClaim && [timantirecall_settings() timantirecall_autoClaimRedPackets];
            BOOL allowOwn = claim && claimOwn && [timantirecall_settings() timantirecall_claimOwnRedPackets];
            BOOL log = diagnose && [timantirecall_settings() timantirecall_packetDiagnostics];
            if (!log && !claim) return;
            for(id record in snapshot)timantirecall_packetObserve(record,owner,epoch,claim,allowOwn,log);
            timantirecall_packetPump();
        } @catch (__unused NSException *exception) {
            // Private observer or presentation failures must not interrupt delivery.
            timantirecall_traceEvent(@"redpack-native-route-aborted");
        } @finally {
            atomic_fetch_sub(&timantirecall_packetPending, 1);
        }
    });
}

BOOL timantirecall_installPacketMonitor(void) {
    if (!NSThread.isMainThread) return NO;
    if (atomic_load(&timantirecall_packetOriginal)) return YES;
    Class cls = objc_getClass("_TtC16NTMsgPushMonitor23NTMsgPushMonitorService");
    if (!cls) cls = objc_getClass("NTMsgPushMonitorService");
    Method method = timantirecall_packetOwnClassMethod(cls, sel_registerName("recvMsgsWithRecords:"));
    const char *args[] = {"@", ":", "@"};
    if (!timantirecall_methodTypes(method, "v", 3, args)) return NO;
    IMP original = method_getImplementation(method);
    if (!original || original == (IMP)timantirecall_packetReceive) return NO;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) { timantirecall_packetSetActive(NO); }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) { timantirecall_packetSetActive(YES); }];
    timantirecall_packetSetActive(UIApplication.sharedApplication.applicationState == UIApplicationStateActive);
    atomic_store(&timantirecall_packetOriginal, original);
    method_setImplementation(method, (IMP)timantirecall_packetReceive);
    timantirecall_traceEvent(@"redpack-monitor-installed");
    return YES;
}
#endif
