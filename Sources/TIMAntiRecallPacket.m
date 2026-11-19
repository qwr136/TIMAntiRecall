#import "TIMAntiRecallPacket.h"
#import "TIMAntiRecallPacketOpen.h"
#import "TIMAntiRecallPacketReceipt.h"
#if defined(TIMANTIRECALL_NATIVE_TEST)
BOOL timantirecall_installPacketMonitor(void) { return NO; } // macOS has no UIKit.
void timantirecall_cancelQueuedPackets(void) {}
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
static NSTimeInterval timantirecall_packetBusyUntil;
static NSUInteger timantirecall_packetSerial;
static __weak UIViewController *timantirecall_packetReturnPresenter;
// Short-lived native record references only; no chat content is copied to disk.
@interface TIMAntiRecallPacketItem : NSObject
@property(nonatomic,strong) id timantirecall_record, timantirecall_wallet;
@property(nonatomic,copy) NSString *timantirecall_owner, *timantirecall_key;
@property(nonatomic,copy) NSDictionary *timantirecall_identity;
@property(nonatomic) unsigned timantirecall_epoch;
@property(nonatomic) BOOL timantirecall_own;
@property(nonatomic) NSTimeInterval timantirecall_enqueued;
@property(nonatomic) NSUInteger timantirecall_serial;
@end
@implementation TIMAntiRecallPacketItem @end
static NSMutableArray<TIMAntiRecallPacketItem *> *timantirecall_packetQueue;
static NSMutableSet<NSString *> *timantirecall_packetQueuedKeys;
static BOOL timantirecall_packetPumpScheduled;
static NSUInteger timantirecall_packetQueuedSerial;
static void timantirecall_packetPump(void);
static void timantirecall_packetSchedule(void) {
    if(timantirecall_packetPumpScheduled || !timantirecall_packetQueue.count)return;
    timantirecall_packetPumpScheduled=YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        timantirecall_packetPumpScheduled=NO;
        @try {timantirecall_packetPump();}
        @catch(__unused NSException *exception) {
            [timantirecall_packetQueue removeAllObjects];[timantirecall_packetQueuedKeys removeAllObjects];
            timantirecall_traceEvent(@"redpack-queue-aborted");
        }
    });
}

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
    for (unsigned depth = 0; controller && depth < 8; depth++) {
        if (controller.presentedViewController || controller.isBeingDismissed || controller.transitionCoordinator) return nil;
        if ([controller isKindOfClass:UINavigationController.class]) controller = ((UINavigationController *)controller).visibleViewController;
        else if ([controller isKindOfClass:UITabBarController.class]) controller = ((UITabBarController *)controller).selectedViewController;
        else return controller.viewIfLoaded.window == window ? controller : nil;
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
static BOOL timantirecall_packetAttempt(id record, id wallet, NSString *owner, unsigned epoch, BOOL autoClaim, BOOL claimOwn, BOOL isOwn, BOOL diagnose) {
    Class router = objc_getClass("NTRedPackRouterService");
    SEL handle = sel_registerName("handleRedPackViewClickWithRootVC:msgRecord:gesture:completion:");
    Method route = timantirecall_packetRoute(router, handle);
    if (diagnose) timantirecall_traceEvent(route ? @"redpack-route-available" : @"redpack-route-unavailable");
    if (!route || !autoClaim) return NO;
    // Scope the trial to types 2/3 in the locked AIO route's supported set.
    // Don't infer wallet grabState enums or bypass TIM's eligibility/confirmation UI.
    int32_t type = 0;
    SEL support = sel_registerName("isSupportRedPackWithMsgType:");
    Method supported = timantirecall_packetOwnClassMethod(router, support);
    const char *supportTypes[] = {"@", ":", "i"};
    if (!timantirecall_packetInt(wallet, sel_registerName("msgType"), &type) || (type != 2 && type != 3) ||
        !timantirecall_methodTypes(supported, "B", 3, supportTypes) ||
        !((BOOL (*)(id, SEL, int32_t))method_getImplementation(supported))(router, support, type)) {
        timantirecall_traceEvent(@"redpack-type-skipped");
        return NO;
    }
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    UIViewController *presenter = timantirecall_packetPresenter();
    if (!presenter || timantirecall_hasPendingPacketUI() || now < timantirecall_packetBusyUntil || !timantirecall_packetStillActive(owner, epoch) ||
        ![timantirecall_settings() timantirecall_autoClaimRedPackets] || (isOwn && (!claimOwn || ![timantirecall_settings() timantirecall_claimOwnRedPackets]))) return NO;
    if (!timantirecall_packetReserve(owner, timantirecall_packetObject(wallet, sel_registerName("billNo")), now)) return NO;
    timantirecall_packetBusyUntil = now + 15;
    timantirecall_packetReturnPresenter=presenter;
    NSUInteger serial = ++timantirecall_packetSerial;
    timantirecall_traceEvent(@"redpack-native-route-attempted");
    SEL amountSelector=sel_registerName("grabbedAmount");
    IMP initialGetter=timantirecall_packetGetter(wallet,amountSelector,"Q");
    uint64_t initialAmount=initialGetter?((uint64_t(*)(id,SEL))initialGetter)(wallet,amountSelector):UINT64_MAX;
    __block BOOL nativeFailure=NO; // main queue only
    TIMAntiRecallPacketCompletion completion = ^(NSDictionary *result, NSError *error) {
        (void)result;
        BOOL failed = error != nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (serial != timantirecall_packetSerial) return;
            nativeFailure=nativeFailure || failed;
            timantirecall_packetBusyUntil = NSProcessInfo.processInfo.systemUptime + 0.15;
            if (timantirecall_packetStillActive(owner, epoch))
                timantirecall_traceEvent(failed ? @"redpack-native-route-error" : @"redpack-native-route-callback");
        });
    };
    NSString *receiptBill=timantirecall_packetObject(wallet,sel_registerName("billNo"));
    TIMAntiRecallPacketReceipt *nativeReceipt=[[TIMAntiRecallPacketReceipt alloc] initWithBill:receiptBill];
    timantirecall_beginPacketOpenWithFailure(presenter,objc_getClass("QQWalletRedPacketMsgService"),^BOOL(void){
        return timantirecall_packetStillActive(owner,epoch) && [timantirecall_settings() timantirecall_autoClaimRedPackets] &&
            (!isOwn || [timantirecall_settings() timantirecall_claimOwnRedPackets]);
    },^BOOL(void){
        // Same native wallet record must transition from no receipt to a positive
        // received amount. Never invent grabState enums or treat a callback as credit.
        IMP getter=timantirecall_packetGetter(wallet,amountSelector,"Q");
        return !nativeFailure && initialAmount==0 && getter && ((uint64_t(*)(id,SEL))getter)(wallet,amountSelector)>0 &&
            timantirecall_packetStillActive(owner,epoch) && [timantirecall_settings() timantirecall_autoClaimRedPackets] &&
            (!isOwn || [timantirecall_settings() timantirecall_claimOwnRedPackets]);
    },^BOOL(void){return nativeFailure;},receiptBill,nativeReceipt);
    ((TIMAntiRecallPacketRoute)method_getImplementation(route))(router, handle, presenter, record, nil, completion);
    return YES;
}

static void timantirecall_packetQueueLog(TIMAntiRecallPacketItem *item, NSString *event) {
    timantirecall_traceEvent([NSString stringWithFormat:@"queue%lu-%@",(unsigned long)item.timantirecall_serial,event]);
}
static void timantirecall_packetRemoveFirst(NSString *event) {
    TIMAntiRecallPacketItem *item=timantirecall_packetQueue.firstObject;
    if(!item)return;
    [timantirecall_packetQueuedKeys removeObject:item.timantirecall_key];
    [timantirecall_packetQueue removeObjectAtIndex:0];
    timantirecall_packetQueueLog(item,event);
}
void timantirecall_cancelQueuedPackets(void) {
    if(!NSThread.isMainThread)return;
    [timantirecall_packetQueue removeAllObjects];[timantirecall_packetQueuedKeys removeAllObjects];
    timantirecall_traceEvent(@"redpack-queue-cancelled-manual");
}
static BOOL timantirecall_packetEnqueue(id record,id wallet,NSString *owner,unsigned epoch,BOOL own) {
    id bill=timantirecall_packetObject(wallet,sel_registerName("billNo"));
    if(![bill isKindOfClass:NSString.class] || ![bill length] || [bill length]>128)return NO;
    NSString *key=[NSString stringWithFormat:@"%@/%@",owner,bill];
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    NSNumber *attempt=timantirecall_packetAttempts[key];
    if([timantirecall_packetQueuedKeys containsObject:key] || (attempt && now-attempt.doubleValue<=120)) {
        timantirecall_traceEvent(@"redpack-queue-duplicate");return NO;
    }
    if(!timantirecall_packetQueue.count && !timantirecall_hasPendingPacketUI())timantirecall_packetReturnPresenter=nil;
    if(timantirecall_packetQueue.count>=32) {timantirecall_traceEvent(@"redpack-queue-full");return NO;}
    if(!timantirecall_packetQueue)timantirecall_packetQueue=[NSMutableArray array];
    if(!timantirecall_packetQueuedKeys)timantirecall_packetQueuedKeys=[NSMutableSet set];
    TIMAntiRecallPacketItem *item=[TIMAntiRecallPacketItem new];
    item.timantirecall_record=record;item.timantirecall_wallet=wallet;item.timantirecall_owner=owner;
    item.timantirecall_identity=timantirecall_recordIdentity(record,owner);
    item.timantirecall_epoch=epoch;item.timantirecall_own=own;item.timantirecall_key=key;
    item.timantirecall_enqueued=now;item.timantirecall_serial=++timantirecall_packetQueuedSerial;
    [timantirecall_packetQueue addObject:item];[timantirecall_packetQueuedKeys addObject:key];
    timantirecall_packetQueueLog(item,@"enqueued");timantirecall_packetPump();return YES;
}
static void timantirecall_packetPump(void) {
    while(timantirecall_packetQueue.count) {
        TIMAntiRecallPacketItem *item=timantirecall_packetQueue.firstObject;
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
        if(!timantirecall_packetStillActive(item.timantirecall_owner,item.timantirecall_epoch) ||
           ![timantirecall_settings() timantirecall_autoClaimRedPackets] ||
           (item.timantirecall_own && ![timantirecall_settings() timantirecall_claimOwnRedPackets])) {
            timantirecall_packetRemoveFirst(@"cancelled-context");continue;
        }
        NSDictionary *identity=timantirecall_recordIdentity(item.timantirecall_record,item.timantirecall_owner);
        NSTimeInterval age=NSDate.date.timeIntervalSince1970-[identity[@"time"] doubleValue];
        NSString *bill=timantirecall_packetObject(item.timantirecall_wallet,sel_registerName("billNo"));
        NSString *currentKey=[bill isKindOfClass:NSString.class]?[NSString stringWithFormat:@"%@/%@",item.timantirecall_owner,bill]:nil;
        if(!identity || ![identity isEqual:item.timantirecall_identity] || ![currentKey isEqual:item.timantirecall_key]) {
            timantirecall_packetRemoveFirst(@"identity-changed");continue;
        }
        if(now-item.timantirecall_enqueued>30 || age>30 || age< -4) {
            timantirecall_packetRemoveFirst(@"expired");continue;
        }
        UIViewController *presenter=timantirecall_packetPresenter();
        if(timantirecall_hasPendingPacketUI() || now<timantirecall_packetBusyUntil || !presenter ||
           (timantirecall_packetReturnPresenter && presenter!=timantirecall_packetReturnPresenter)) {
            timantirecall_packetSchedule();return;
        }
        BOOL started=timantirecall_packetAttempt(item.timantirecall_record,item.timantirecall_wallet,
            item.timantirecall_owner,item.timantirecall_epoch,YES,
            [timantirecall_settings() timantirecall_claimOwnRedPackets],item.timantirecall_own,
            [timantirecall_settings() timantirecall_packetDiagnostics]);
        timantirecall_packetRemoveFirst(started?@"started":@"rejected");
        if(started) {timantirecall_packetSchedule();return;}
    }
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
    if(autoClaim)return timantirecall_packetEnqueue(record,wallet,owner,epoch,own);
    return timantirecall_packetAttempt(record,wallet,owner,epoch,NO,claimOwn,own,diagnose);
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
            for (id record in snapshot)
                timantirecall_packetObserve(record, owner, epoch, claim, allowOwn, log);
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
