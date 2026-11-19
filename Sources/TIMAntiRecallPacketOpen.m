#import "TIMAntiRecallPacketOpen.h"
#ifdef TIMANTIRECALL_NATIVE_TEST
BOOL timantirecall_beginPacketOpenForBill(id presenter,Class service,NSString *bill,BOOL (^valid)(void),BOOL (^receipt)(void),BOOL (^returned)(void),BOOL (^failed)(void)) {
    (void)presenter;(void)service;(void)bill;(void)valid;(void)receipt;(void)returned;(void)failed;return NO;
}
void timantirecall_settlePacketUIForNext(void) {}
void timantirecall_beginPacketOpen(id presenter, Class walletService, BOOL (^isValid)(void)) {
    (void)presenter;(void)walletService;(void)isValid;
}
void timantirecall_beginPacketOpenWithReceipt(id presenter, Class walletService, BOOL (^isValid)(void), BOOL (^didReceive)(void)) {
    (void)presenter;(void)walletService;(void)isValid;(void)didReceive;
}
BOOL timantirecall_hasPendingPacketUI(void) {return NO;}
#else
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallTrace.h"
#import "TIMAntiRecallPacketWallet.h"
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

@interface TIMAntiRecallPacketOpenContext : NSObject
@property(nonatomic,weak) UIWindow *timantirecall_window;
@property(nonatomic,weak) UIViewController *timantirecall_presenter;
@property(nonatomic,weak) UIView *timantirecall_page;
@property(nonatomic,copy) NSString *timantirecall_bill;
@property(nonatomic,copy) BOOL (^timantirecall_returned)(void);
@property(nonatomic,copy) BOOL (^timantirecall_failed)(void);
@property(nonatomic) BOOL timantirecall_slotSeen, timantirecall_scanDone, timantirecall_closing;
@property(nonatomic) NSTimeInterval timantirecall_pressed;
@property(nonatomic,strong) NSHashTable<UIView *> *timantirecall_before;
@property(nonatomic,strong) NSMutableSet<NSString *> *timantirecall_logged;
@property(nonatomic,copy) BOOL (^timantirecall_valid)(void);
@property(nonatomic,copy) BOOL (^timantirecall_received)(void);
@property(nonatomic,weak) id timantirecall_openedReceiver;

@property(nonatomic) BOOL timantirecall_opened, timantirecall_dispatching;
@property(nonatomic) Class timantirecall_service;
@property(nonatomic) NSTimeInterval timantirecall_deadline;
@property(nonatomic) NSUInteger timantirecall_serial, timantirecall_logs;
@end
@implementation TIMAntiRecallPacketOpenContext @end
static TIMAntiRecallPacketOpenContext *timantirecall_openContext; // main queue
static NSUInteger timantirecall_openSerial;
static _Atomic(IMP) timantirecall_controlOriginal;
typedef void (*TIMAntiRecallControlActionIMP)(id,SEL,SEL,id,UIEvent *);

static BOOL timantirecall_openValid(TIMAntiRecallPacketOpenContext *context) {
    UIWindow *window=context.timantirecall_window;
    return context && context==timantirecall_openContext &&
        NSProcessInfo.processInfo.systemUptime<context.timantirecall_deadline &&
        UIApplication.sharedApplication.applicationState==UIApplicationStateActive &&
        window && !window.hidden && window.isKeyWindow && window.windowLevel==UIWindowLevelNormal &&
        (!window.windowScene || window.windowScene.activationState==UISceneActivationStateForegroundActive) &&
        context.timantirecall_valid && context.timantirecall_valid();
}
static NSArray<UIView *> *timantirecall_openViews(UIWindow *window) {
    if(!window)return nil;
    NSMutableArray<UIView *> *pending=[NSMutableArray arrayWithObject:window];
    for(NSUInteger index=0;index<pending.count;index++) {
        NSArray<UIView *> *children=pending[index].subviews;
        if(pending.count+children.count>1024)return nil; // incomplete scans never click
        [pending addObjectsFromArray:children];
    }
    return pending;
}
static NSString *timantirecall_openIdentifier(const char *raw) {
    if(!raw)return @"none";
    NSString *input=[NSString stringWithUTF8String:raw]?:@"unknown";
    NSMutableString *safe=[NSMutableString string];
    for(NSUInteger i=0;i<MIN(input.length,(NSUInteger)100);i++) {
        unichar ch=[input characterAtIndex:i];
        BOOL allowed=(ch>='a'&&ch<='z')||(ch>='A'&&ch<='Z')||(ch>='0'&&ch<='9')||strchr("_-.:@?",(int)ch)!=NULL;
        [safe appendFormat:@"%C",(unichar)(allowed?ch:'_')];
    }
    return safe;
}
static void timantirecall_openLog(TIMAntiRecallPacketOpenContext *context, NSString *phase, const char *name) {
    if(context.timantirecall_logs>=32 || ![timantirecall_settings() timantirecall_packetDiagnostics])return;
    context.timantirecall_logs++;
    timantirecall_traceEvent([NSString stringWithFormat:@"open%lu-%@-%@",(unsigned long)context.timantirecall_serial,phase,timantirecall_openIdentifier(name)]);
}
// Locked TIM WeakProxy exposes target @16 and forwardingTargetForSelector: @24.
// Its methodSignatureForSelector: is a generic fallback, not an action ABI proof.
static id timantirecall_openReceiver(id target, SEL action) {
    if(!target || !action)return nil;
    Class proxy=objc_getClass("WeakProxy");
    if(proxy && object_getClass(target)==proxy) {
        Method getter=class_getInstanceMethod(proxy,sel_registerName("target"));
        Method forwarding=class_getInstanceMethod(proxy,sel_registerName("forwardingTargetForSelector:"));
        const char *getTypes[]={"@",":"};const char *forwardTypes[]={"@",":",":"};
        if(!timantirecall_methodTypes(getter,"@",2,getTypes) || !timantirecall_methodTypes(forwarding,"@",3,forwardTypes))return nil;
        id receiver=((id(*)(id,SEL))method_getImplementation(getter))(target,sel_registerName("target"));
        if(!receiver || receiver==target || object_getClass(receiver)==proxy)return nil;
        id forwarded=((id(*)(id,SEL,SEL))method_getImplementation(forwarding))(target,sel_registerName("forwardingTargetForSelector:"),action);
        if(forwarded!=receiver)return nil;
        return class_getInstanceMethod(object_getClass(receiver),action)?receiver:nil;
    }
    return class_getInstanceMethod(object_getClass(target),action)?target:nil;
}
static void timantirecall_openBinding(TIMAntiRecallPacketOpenContext *context, UIControl *control, id target, SEL action, BOOL hit) {
    if(![timantirecall_settings() timantirecall_packetDiagnostics])return;
    NSString *key=[NSString stringWithFormat:@"%p-%p-%@",control,target,NSStringFromSelector(action)];
    if(!hit && [context.timantirecall_logged containsObject:key])return;
    [context.timantirecall_logged addObject:key];
    timantirecall_openLog(context,hit?@"manual-control":@"candidate-control",class_getName(control.class));
    timantirecall_openLog(context,@"target",target?class_getName(object_getClass(target)):NULL);
    timantirecall_openLog(context,@"action",action?sel_getName(action):NULL);
    id receiver=timantirecall_openReceiver(target,action);
    timantirecall_openLog(context,@"resolved-target",receiver?class_getName(object_getClass(receiver)):NULL);
    Method method=receiver?class_getInstanceMethod(object_getClass(receiver),action):NULL;
    timantirecall_openLog(context,@"encoding",method?method_getTypeEncoding(method):NULL);
    const char *image=receiver?class_getImageName(object_getClass(receiver)):NULL;
    if(image) {const char *last=strrchr(image,'/');timantirecall_openLog(context,@"image",last?last+1:image);}
}
static BOOL timantirecall_openLabel(UIControl *control) {
    NSArray *labels=@[control.accessibilityLabel?:@"",[control isKindOfClass:UIButton.class]?((UIButton *)control).currentTitle?:@"":@""];
    for(id value in labels) {
        if(![value isKindOfClass:NSString.class])continue;
        NSString *label=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if([@[@"开",@"開",@"开红包",@"開紅包"] containsObject:label])return YES;
    }
    return NO;
}
static BOOL timantirecall_openActionABI(Method method) {
    if(!method)return NO;
    unsigned colons=0;
    for(const char *name=sel_getName(method_getName(method));*name;name++)if(*name==':')colons++;
    if(colons>2 || method_getNumberOfArguments(method)!=colons+2)return NO;
    const char *zero[]={"@",":"};const char *one[]={"@",":","@"};const char *two[]={"@",":","@","@"};
    return timantirecall_methodTypes(method,"v",2,zero)||timantirecall_methodTypes(method,"v",3,one)||timantirecall_methodTypes(method,"v",4,two);
}
static BOOL timantirecall_openWalletAction(id target, SEL action, Class service) {
    if(!target||!service)return NO;
    target=timantirecall_openReceiver(target,action);
    if(!target)return NO;
    Method method=class_getInstanceMethod(object_getClass(target),action);
    if(!timantirecall_openActionABI(method))return NO;
    const char *owner=class_getImageName(service),*image=class_getImageName(object_getClass(target));
    if(owner && image && !strcmp(owner,image))return YES;
    Method entry=class_getClassMethod(service,sel_registerName("grabRedPackWithMsgRecord:rootVC:completion:"));
    Dl_info targetInfo={0},walletInfo={0};
    return entry && dladdr((const void *)method_getImplementation(method),&targetInfo) &&
        dladdr((const void *)method_getImplementation(entry),&walletInfo) && targetInfo.dli_fbase==walletInfo.dli_fbase;
}
static BOOL timantirecall_openVisible(UIControl *control, UIWindow *window) {
    if(!control.enabled || !control.userInteractionEnabled || control.window!=window || CGRectIsEmpty(control.bounds))return NO;
    for(UIView *view=control;view;view=view.superview)
        if(view.hidden || view.alpha<0.05 || !view.userInteractionEnabled)return NO;
    CGPoint point=CGPointMake(CGRectGetMidX(control.bounds),CGRectGetMidY(control.bounds));
    UIView *hit=[window hitTest:[control convertPoint:point toView:window] withEvent:nil];
    return hit && (hit==control || [hit isDescendantOfView:control]);
}

static void timantirecall_endPacketUI(TIMAntiRecallPacketOpenContext *context) {
    if(timantirecall_openContext!=context)return;
    timantirecall_disarmPacketFinish();timantirecall_openContext=nil;
}
static BOOL timantirecall_popupAttached(TIMAntiRecallPacketOpenContext *context) {
    UIView *page=context.timantirecall_page;
    return page && page.window && page.window==context.timantirecall_window;
}
static UIControl *timantirecall_findCloseControl(TIMAntiRecallPacketOpenContext *context) {
    NSArray<UIView *> *views=timantirecall_openViews(context.timantirecall_window);
    UIControl *candidate=nil;
    for(UIView *view in views) {
        if([context.timantirecall_before containsObject:view] || ![view isKindOfClass:UIControl.class])continue;
        UIControl *control=(UIControl *)view;
        if(!timantirecall_openVisible(control,context.timantirecall_window))continue;
        NSUInteger bindings=0;id target=nil;SEL action=NULL;
        for(id item in control.allTargets)for(NSString *name in [control actionsForTarget:item forControlEvent:UIControlEventTouchUpInside]) {
            bindings++;target=item;action=NSSelectorFromString(name);
        }
        if(bindings!=1 || action!=sel_registerName("dismissView") ||
           timantirecall_openReceiver(target,action)!=context.timantirecall_openedReceiver ||
           !timantirecall_openWalletAction(target,action,context.timantirecall_service))continue;
        if(candidate)return nil;candidate=control;
    }
    return candidate;
}
static void timantirecall_closeCheck(TIMAntiRecallPacketOpenContext *context,BOOL last,BOOL queued) {
    if(!timantirecall_openValid(context))return;
    if(!timantirecall_popupAttached(context)) {timantirecall_endPacketUI(context);return;}
    if(context.timantirecall_closing)return;
    if(!timantirecall_walletCanAcceptPacket(context.timantirecall_service)) {
        context.timantirecall_slotSeen=YES;return;
    }
    BOOL model=context.timantirecall_received && context.timantirecall_received();
    id receiver=context.timantirecall_openedReceiver;
    BOOL native=receiver && object_getClass(receiver)==objc_getClass("QQWalletPreOpenHBView");
    BOOL released=context.timantirecall_slotSeen || (context.timantirecall_returned && context.timantirecall_returned());
    // Native success animation dismisses itself. For another waiting packet an idle,
    // ordinary pre-open sheet may use its own registered X even without a receipt.
    if(native) {
        if(!queued || !released || NSProcessInfo.processInfo.systemUptime-context.timantirecall_pressed<0.18 ||
           !timantirecall_walletPopupCanRetire(receiver))return;
    }else if(!model) {
        if(last)timantirecall_openLog(context,@"close","skipped-receipt-unconfirmed");
        return;
    }
    UIControl *control=timantirecall_findCloseControl(context);
    if(!control || !receiver)return;
    __attribute__((objc_precise_lifetime)) id keepReceiver=receiver;
    if(!keepReceiver)return;
    timantirecall_disarmPacketFinish();
    context.timantirecall_closing=YES;context.timantirecall_dispatching=YES;
    timantirecall_openLog(context,@"close",native?"settled-popup-retired":"model-confirmed-dispatched");
    @try {[control sendActionsForControlEvents:UIControlEventTouchUpInside];}
    @finally {context.timantirecall_dispatching=NO;}
    if(!timantirecall_popupAttached(context))timantirecall_endPacketUI(context);
}
static void timantirecall_scheduleClose(TIMAntiRecallPacketOpenContext *context) {
    if(!context.timantirecall_bill.length && !context.timantirecall_received) {timantirecall_endPacketUI(context);return;}
    const double delays[]={0.12,0.25,0.5,0.9,1.6,2.8,5.0,8.0};
    for(unsigned i=0;i<8;i++) {
        BOOL last=i==7;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delays[i]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            @try {if(timantirecall_openContext==context)timantirecall_closeCheck(context,last,NO);}
            @catch(__unused NSException *exception) {timantirecall_endPacketUI(context);}
        });
    }
}

static void timantirecall_openScan(TIMAntiRecallPacketOpenContext *context, BOOL last) {
    if(!timantirecall_openValid(context)) {timantirecall_endPacketUI(context);return;}
    NSArray<UIView *> *views=timantirecall_openViews(context.timantirecall_window);
    if(!views) {timantirecall_openLog(context,@"scan","tree-limit");return;}
    if(context.timantirecall_opened)return;
    UIControl *candidate=nil;id candidateReceiver=nil;
    for(UIView *view in views) {
        if(![view isKindOfClass:UIControl.class] || [context.timantirecall_before containsObject:view])continue;
        UIControl *control=(UIControl *)view;
        if(!timantirecall_openVisible(control,context.timantirecall_window))continue;
        NSUInteger bindings=0;id selectedTarget=nil;SEL selectedAction=NULL;
        for(id target in control.allTargets) {
            NSArray<NSString *> *actions=[control actionsForTarget:target forControlEvent:UIControlEventTouchUpInside];
            for(NSString *name in actions) {
                bindings++;selectedTarget=target;selectedAction=NSSelectorFromString(name);
                if(context.timantirecall_logged.count<4)timantirecall_openBinding(context,control,target,selectedAction,NO);
            }
        }
        if(bindings!=1)continue;
        id receiver=timantirecall_openReceiver(selectedTarget,selectedAction);
        if(!receiver || !timantirecall_openWalletAction(selectedTarget,selectedAction,context.timantirecall_service))continue;
        if(selectedAction==sel_registerName("dismissView"))continue;
        // This exact image-button binding was observed in the user's TIM trace.
        BOOL observedProxyOpen=selectedAction==sel_registerName("openButtonClick") && receiver!=selectedTarget &&
            object_getClass(selectedTarget)==objc_getClass("WeakProxy");
        if(!timantirecall_openLabel(control) && !observedProxyOpen)continue;
        Class preOpen=objc_getClass("QQWalletPreOpenHBView");
        if(preOpen && object_getClass(receiver)==preOpen && !timantirecall_walletPopupMatchesBill(receiver,context.timantirecall_bill)) {
            timantirecall_openLog(context,@"skip","popup-bill-mismatch");continue;
        }
        if(candidate) {timantirecall_openLog(context,@"skip","ambiguous-buttons");return;}
        candidate=control;candidateReceiver=receiver;
    }
    if(candidate && timantirecall_openValid(context)) {
        // Exactly one native control event. Never guess a private selector,
        // synthesize a touch, drive a payment prompt, or click twice.
        __attribute__((objc_precise_lifetime)) id keepReceiver=candidateReceiver;
        if(!keepReceiver)return;
        context.timantirecall_openedReceiver=keepReceiver;
        UIView *page=candidate;
        for(NSUInteger depth=0;page.superview && depth<32 && ![context.timantirecall_before containsObject:page.superview];depth++)page=page.superview;
        context.timantirecall_page=[keepReceiver isKindOfClass:UIView.class]?(UIView *)keepReceiver:page;
        context.timantirecall_pressed=NSProcessInfo.processInfo.systemUptime;
        context.timantirecall_opened=YES;context.timantirecall_dispatching=YES;
        __weak TIMAntiRecallPacketOpenContext *weakContext=context;
        timantirecall_armPacketFinish(keepReceiver,context.timantirecall_bill,^BOOL(void){
            TIMAntiRecallPacketOpenContext *live=weakContext;
            return timantirecall_openValid(live) && !(live.timantirecall_failed && live.timantirecall_failed());
        },^{
            TIMAntiRecallPacketOpenContext *live=weakContext;
            if(live && live==timantirecall_openContext) {
                live.timantirecall_closing=YES;
                timantirecall_openLog(live,@"close","native-dismiss-complete");
                timantirecall_endPacketUI(live);
            }
        });
        timantirecall_openLog(context,@"button","dispatched");
        @try { [candidate sendActionsForControlEvents:UIControlEventTouchUpInside]; }
        @finally {context.timantirecall_dispatching=NO;}
        timantirecall_openLog(context,@"button","returned");
        context.timantirecall_slotSeen=!timantirecall_walletCanAcceptPacket(context.timantirecall_service);
        timantirecall_scheduleClose(context);
    }else if(last) {
        context.timantirecall_scanDone=YES;
        timantirecall_openLog(context,@"button","unresolved-manual-observation-only");
    }
}
static void timantirecall_controlAction(id receiver, SEL command, SEL action, id target, UIEvent *event) {
    @try {
        TIMAntiRecallPacketOpenContext *context=NSThread.isMainThread?timantirecall_openContext:nil;
        if(context && !context.timantirecall_dispatching && [receiver isKindOfClass:UIControl.class] && ((UIControl *)receiver).window==context.timantirecall_window) {
            if(timantirecall_openValid(context) && ![context.timantirecall_before containsObject:receiver])
                timantirecall_openBinding(context,receiver,target,action,YES);
            // Any intervening native button action means the user owns the UI.
            timantirecall_endPacketUI(context);
        }
    } @catch(__unused NSException *exception) {}
    TIMAntiRecallControlActionIMP original=(TIMAntiRecallControlActionIMP)atomic_load(&timantirecall_controlOriginal);
    original(receiver,command,action,target,event);
}
static BOOL timantirecall_installOpenObserver(void) {
    if(atomic_load(&timantirecall_controlOriginal))return YES;
    SEL action=@selector(sendAction:to:forEvent:);
    Method method=class_getInstanceMethod(UIControl.class,action);
    const char *types[]={"@",":",":","@","@"};
    if(!timantirecall_methodTypes(method,"v",5,types))return NO;
    IMP original=method_getImplementation(method);
    if(!original || original==(IMP)timantirecall_controlAction)return NO;
    atomic_store(&timantirecall_controlOriginal,original);
    method_setImplementation(method,(IMP)timantirecall_controlAction);
    return YES;
}
BOOL timantirecall_hasPendingPacketUI(void) {
    if(!NSThread.isMainThread || !timantirecall_openContext)return NO;
    TIMAntiRecallPacketOpenContext *context=timantirecall_openContext;
    if(timantirecall_popupAttached(context))return YES;
    if(context.timantirecall_opened || !timantirecall_openValid(context)) {timantirecall_endPacketUI(context);return NO;}
    return context.timantirecall_bill.length!=0; // A standalone probe owns no route before opening.
}
void timantirecall_settlePacketUIForNext(void) {
    TIMAntiRecallPacketOpenContext *context=timantirecall_openContext;
    if(!NSThread.isMainThread || !timantirecall_openValid(context))return;
    if(context.timantirecall_opened) {timantirecall_closeCheck(context,NO,YES);return;}
    if(!context.timantirecall_returned || !context.timantirecall_returned() ||
       !(context.timantirecall_scanDone || (context.timantirecall_failed && context.timantirecall_failed())))return;
    if(!timantirecall_walletCanAcceptPacket(context.timantirecall_service))return;
    UIViewController *origin=context.timantirecall_presenter;
    if(!origin || origin.viewIfLoaded.window!=context.timantirecall_window || origin.presentedViewController || origin.transitionCoordinator)return;
    NSArray *views=timantirecall_openViews(context.timantirecall_window);
    if(!views)return;
    for(UIView *view in views)if(![context.timantirecall_before containsObject:view] && !view.hidden && view.alpha>=0.05)return;
    timantirecall_openLog(context,@"route","finished-without-popup");timantirecall_endPacketUI(context);
}
void timantirecall_beginPacketOpen(id presenter,Class service,BOOL (^valid)(void)) {
    timantirecall_beginPacketOpenWithReceipt(presenter,service,valid,nil);
}
void timantirecall_beginPacketOpenWithReceipt(id presenter,Class service,BOOL (^valid)(void),BOOL (^receipt)(void)) {
    timantirecall_beginPacketOpenForBill(presenter,service,nil,valid,receipt,nil,nil);
}
BOOL timantirecall_beginPacketOpenForBill(id presenter,Class walletService,NSString *bill,BOOL (^isValid)(void),BOOL (^didReceive)(void),BOOL (^routeReturned)(void),BOOL (^routeFailed)(void)) {
    if(!NSThread.isMainThread)return NO;
    timantirecall_endPacketUI(timantirecall_openContext);
    if(![presenter isKindOfClass:UIViewController.class] || !walletService || !isValid || !isValid())return NO;
    UIWindow *window=((UIViewController *)presenter).viewIfLoaded.window;
    NSArray<UIView *> *before=timantirecall_openViews(window);
    if(!before || !timantirecall_installOpenObserver()) {
        timantirecall_traceEvent(@"redpack-open-unavailable-or-tree-limit");return NO;
    }
    TIMAntiRecallPacketOpenContext *context=[TIMAntiRecallPacketOpenContext new];
    context.timantirecall_window=window;context.timantirecall_service=walletService;context.timantirecall_presenter=presenter;
    context.timantirecall_bill=bill;context.timantirecall_returned=routeReturned;context.timantirecall_failed=routeFailed;
    context.timantirecall_valid=isValid;context.timantirecall_received=didReceive;context.timantirecall_deadline=NSProcessInfo.processInfo.systemUptime+30;
    context.timantirecall_before=[NSHashTable weakObjectsHashTable];
    for(UIView *view in before)[context.timantirecall_before addObject:view];
    context.timantirecall_logged=[NSMutableSet set];context.timantirecall_serial=++timantirecall_openSerial;
    timantirecall_openContext=context;
    timantirecall_openLog(context,@"button","armed");
    const double delays[]={0.08,0.18,0.32,0.52,0.8,1.2,1.8,2.8};
    for(unsigned index=0;index<8;index++) {
        BOOL last=index==7;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delays[index]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            @try {if(timantirecall_openContext==context)timantirecall_openScan(context,last);}
            @catch(__unused NSException *exception) {
                timantirecall_endPacketUI(context);
                timantirecall_openLog(context,@"button","aborted-no-retry");
            }
        });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(!timantirecall_popupAttached(context))timantirecall_endPacketUI(context);
        else if(timantirecall_openContext==context)timantirecall_disarmPacketFinish();
    });
    return YES;
}
#endif
