#import "TIMAntiRecallPacketOpen.h"
#ifdef TIMANTIRECALL_NATIVE_TEST
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
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

@interface TIMAntiRecallPacketOpenContext : NSObject
@property(nonatomic,weak) UIWindow *timantirecall_window;
@property(nonatomic,strong) NSHashTable<UIView *> *timantirecall_before;
@property(nonatomic,strong) NSMutableSet<NSString *> *timantirecall_logged;
@property(nonatomic,copy) BOOL (^timantirecall_valid)(void);
@property(nonatomic,copy) BOOL (^timantirecall_received)(void);
@property(nonatomic,weak) UIControl *timantirecall_closeControl;
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

static void timantirecall_closeCheck(TIMAntiRecallPacketOpenContext *context, BOOL last) {
    if(!timantirecall_openValid(context)) {if(timantirecall_openContext==context)timantirecall_openContext=nil;return;}
    if(!context.timantirecall_received || !context.timantirecall_received()) {
        if(last) {timantirecall_openLog(context,@"close","skipped-receipt-unconfirmed");timantirecall_openContext=nil;}
        return;
    }
    UIControl *control=context.timantirecall_closeControl;
    if(!control) {timantirecall_openLog(context,@"close","skipped-no-unique-control");timantirecall_openContext=nil;return;}
    if(!control.window) {timantirecall_openLog(context,@"close","owned-view-already-gone");timantirecall_openContext=nil;return;}
    if(!timantirecall_openVisible(control,context.timantirecall_window))return;
    NSUInteger count=0;id selected=nil;SEL action=NULL;
    for(id target in control.allTargets)for(NSString *name in [control actionsForTarget:target forControlEvent:UIControlEventTouchUpInside]) {
        count++;selected=target;action=NSSelectorFromString(name);
    }
    __attribute__((objc_precise_lifetime)) id receiver=timantirecall_openReceiver(selected,action);
    if(count!=1 || action!=sel_registerName("dismissView") || !receiver || receiver!=context.timantirecall_openedReceiver ||
       !timantirecall_openWalletAction(selected,action,context.timantirecall_service)) {
        if(last){timantirecall_openLog(context,@"close","skipped-binding-changed");timantirecall_openContext=nil;}
        return;
    }
    timantirecall_openLog(context,@"receipt","model-confirmed");
    timantirecall_openContext=nil;
    timantirecall_openLog(context,@"close","dispatched");
    [control sendActionsForControlEvents:UIControlEventTouchUpInside];
    timantirecall_openLog(context,@"close","returned");
}
static void timantirecall_scheduleClose(TIMAntiRecallPacketOpenContext *context) {
    if(!context.timantirecall_received) {timantirecall_openContext=nil;return;}
    const double delays[]={0.3,0.7,1.4,2.8,5.5,9.5};
    for(unsigned i=0;i<6;i++) {
        BOOL last=i==5;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delays[i]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            @try {if(timantirecall_openContext==context)timantirecall_closeCheck(context,last);}
            @catch(__unused NSException *exception) {if(timantirecall_openContext==context)timantirecall_openContext=nil;}
        });
    }
}

static void timantirecall_openScan(TIMAntiRecallPacketOpenContext *context, BOOL last) {
    if(!timantirecall_openValid(context)) {if(timantirecall_openContext==context)timantirecall_openContext=nil;return;}
    NSArray<UIView *> *views=timantirecall_openViews(context.timantirecall_window);
    if(!views) {timantirecall_openLog(context,@"scan","tree-limit");return;}
    if(context.timantirecall_opened)return;
    UIControl *candidate=nil;id candidateReceiver=nil;
    NSMutableArray<UIControl *> *closers=[NSMutableArray array];
    NSMutableArray *closeReceivers=[NSMutableArray array];
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
        if(selectedAction==sel_registerName("dismissView")) { [closers addObject:control];[closeReceivers addObject:receiver];continue; }
        // This exact image-button binding was observed in the user's TIM trace.
        BOOL observedProxyOpen=selectedAction==sel_registerName("openButtonClick") && receiver!=selectedTarget &&
            object_getClass(selectedTarget)==objc_getClass("WeakProxy");
        if(!timantirecall_openLabel(control) && !observedProxyOpen)continue;
        if(candidate) {timantirecall_openLog(context,@"skip","ambiguous-buttons");return;}
        candidate=control;candidateReceiver=receiver;
    }
    if(candidate && timantirecall_openValid(context)) {
        // Exactly one native control event. Never guess a private selector,
        // synthesize a touch, drive a payment prompt, or click twice.
        __attribute__((objc_precise_lifetime)) id keepReceiver=candidateReceiver;
        context.timantirecall_openedReceiver=keepReceiver;
        NSUInteger closeCount=0;
        for(NSUInteger i=0;i<closers.count;i++)if(closeReceivers[i]==keepReceiver) {
            closeCount++;context.timantirecall_closeControl=closers[i];
        }
        if(closeCount!=1)context.timantirecall_closeControl=nil;
        context.timantirecall_opened=YES;context.timantirecall_dispatching=YES;
        timantirecall_openLog(context,@"button","dispatched");
        @try { [candidate sendActionsForControlEvents:UIControlEventTouchUpInside]; }
        @finally {context.timantirecall_dispatching=NO;}
        timantirecall_openLog(context,@"button","returned");
        timantirecall_scheduleClose(context);
    }else if(last) {
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
            timantirecall_openContext=nil;
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
    return NSThread.isMainThread && timantirecall_openContext.timantirecall_opened && timantirecall_openValid(timantirecall_openContext);
}
void timantirecall_beginPacketOpen(id presenter, Class walletService, BOOL (^isValid)(void)) {
    timantirecall_beginPacketOpenWithReceipt(presenter,walletService,isValid,nil);
}
void timantirecall_beginPacketOpenWithReceipt(id presenter, Class walletService, BOOL (^isValid)(void), BOOL (^didReceive)(void)) {
    if(!NSThread.isMainThread)return;
    timantirecall_openContext=nil;
    if(![presenter isKindOfClass:UIViewController.class] || !walletService || !isValid || !isValid())return;
    UIWindow *window=((UIViewController *)presenter).viewIfLoaded.window;
    NSArray<UIView *> *before=timantirecall_openViews(window);
    if(!before || !timantirecall_installOpenObserver()) {
        timantirecall_traceEvent(@"redpack-open-unavailable-or-tree-limit");return;
    }
    TIMAntiRecallPacketOpenContext *context=[TIMAntiRecallPacketOpenContext new];
    context.timantirecall_window=window;context.timantirecall_service=walletService;
    context.timantirecall_valid=isValid;context.timantirecall_received=didReceive;context.timantirecall_deadline=NSProcessInfo.processInfo.systemUptime+30;
    context.timantirecall_before=[NSHashTable weakObjectsHashTable];
    for(UIView *view in before)[context.timantirecall_before addObject:view];
    context.timantirecall_logged=[NSMutableSet set];context.timantirecall_serial=++timantirecall_openSerial;
    timantirecall_openContext=context;
    timantirecall_openLog(context,@"button","armed");
    const double delays[]={0.15,0.4,0.8,1.4,2.4,4.0};
    for(unsigned index=0;index<6;index++) {
        BOOL last=index==5;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delays[index]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            @try {if(timantirecall_openContext==context)timantirecall_openScan(context,last);}
            @catch(__unused NSException *exception) {
                if(timantirecall_openContext==context)timantirecall_openContext=nil;
                timantirecall_openLog(context,@"button","aborted-no-retry");
            }
        });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(timantirecall_openContext==context)timantirecall_openContext=nil;
    });
}
#endif
