#import "TIMAntiRecallPacketSilent.h"
#ifdef TIMANTIRECALL_NATIVE_TEST
BOOL timantirecall_silentPacketReady(Class service) {(void)service;return NO;}
BOOL timantirecall_beginSilentPacket(Class service,NSString *bill,BOOL (^valid)(void),void (^finished)(NSString *,NSString *),void (^invoke)(TIMAntiRecallSilentReceipt)) {
    (void)service;(void)bill;(void)valid;(void)finished;(void)invoke;return NO;
}
#else
#import "TIMAntiRecallPacketWallet.h"
#import "TIMAntiRecallPacketToast.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallTrace.h"
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

typedef void (*TIMAntiRecallSilentStartIMP)(id,SEL,id,id,TIMAntiRecallSilentReceipt);
typedef void (*TIMAntiRecallSilentViewIMP)(id,SEL,id);
typedef void (*TIMAntiRecallSilentVoidIMP)(id,SEL);
typedef void (*TIMAntiRecallSilentDismissIMP)(id,SEL,BOOL,void (^)(void));
@interface TIMAntiRecallSilentPacket : NSObject
@property(nonatomic,copy) NSString *timantirecall_bill,*timantirecall_text,*timantirecall_phase;
@property(nonatomic,copy) BOOL (^timantirecall_valid)(void);
@property(nonatomic,copy) void (^timantirecall_finished)(NSString *,NSString *);
@property(nonatomic,strong) id timantirecall_wallet,timantirecall_service,timantirecall_data;
@property(nonatomic,strong) UIViewController *timantirecall_controller;
@property(nonatomic,copy) TIMAntiRecallSilentReceipt timantirecall_pre;
@property(nonatomic) BOOL timantirecall_entering,timantirecall_starting,timantirecall_preResolved,timantirecall_submitted,timantirecall_callback;
@property(nonatomic) NSTimeInterval timantirecall_deadline;
@end
@implementation TIMAntiRecallSilentPacket @end
static TIMAntiRecallSilentPacket *timantirecall_silent; // main queue only
static dispatch_block_t timantirecall_silentManual; // one native manual request gets priority after the owned slots release
static Class timantirecall_silentImageClass;
static const void *timantirecall_silentImage;
static Ivar timantirecall_silentLowSlot;
static _Atomic(IMP) timantirecall_silentStartOriginal,timantirecall_silentViewOriginal;
static _Atomic(IMP) timantirecall_silentLoadingOriginal,timantirecall_silentDismissOriginal;
static char timantirecall_silentControllerKey;

static IMP timantirecall_silentMethod(Class cls,const char *name,BOOL meta,const char *result,unsigned count,const char *types[]) {
    if(!cls)return NULL;
    Method method=meta?class_getClassMethod(cls,sel_registerName(name)):class_getInstanceMethod(cls,sel_registerName(name));
    if(!timantirecall_methodTypes(method,result,count,types))return NULL;
    IMP imp=method_getImplementation(method);
#ifndef TIMANTIRECALL_UI_TEST
    Dl_info image={0};
    if(!imp || !dladdr((const void *)imp,&image) || image.dli_fbase!=timantirecall_silentImage)return NULL;
#endif
    return imp;
}
static id timantirecall_silentObject(id object,const char *name,BOOL meta) {
    const char *args[]={"@",":"};
    IMP getter=timantirecall_silentMethod(meta?object:object_getClass(object),name,meta,"@",2,args);
    return getter?((id(*)(id,SEL))getter)(object,sel_registerName(name)):nil;
}
static TIMAntiRecallSilentReceipt timantirecall_silentSlot(id object,const char *name,BOOL *known) {
    const char *args[]={"@",":"};
    IMP getter=timantirecall_silentMethod(object_getClass(object),name,NO,"@?",2,args);
    if(known)*known=getter!=NULL;
    return getter?((TIMAntiRecallSilentReceipt(*)(id,SEL))getter)(object,sel_registerName(name)):nil;
}
static BOOL timantirecall_silentIdle(id service,id wallet) {
    BOOL preKnown=NO,claimKnown=NO;
    id pre=timantirecall_silentSlot(service,"preGrapHBCallback",&preKnown);
    id claim=timantirecall_silentSlot(service,"grapHBCallback",&claimKnown);
    const char *args[]={"@",":"};
    IMP paying=timantirecall_silentMethod(object_getClass(wallet),"isPaying",NO,"B",2,args);
    return preKnown && claimKnown && paying && timantirecall_silentLowSlot &&
        !pre && !claim && !object_getIvar(wallet,timantirecall_silentLowSlot) &&
        !((BOOL(*)(id,SEL))paying)(wallet,sel_registerName("isPaying"));
}
static BOOL timantirecall_silentDataMatches(TIMAntiRecallSilentPacket *request,id data) {
    if(!data || object_getClass(data)!=objc_getClass("QQWalletGrapHBData"))return NO;
    id aio=timantirecall_silentObject(data,"aioData",NO);
    if(!aio || object_getClass(aio)!=objc_getClass("QQWalletGrapHBAIOData"))return NO;
    id bill=timantirecall_silentObject(aio,"listId",NO);
    return [bill isKindOfClass:NSString.class] && [bill isEqualToString:request.timantirecall_bill];
}
static BOOL timantirecall_silentOwns(TIMAntiRecallSilentPacket *request,id data) {
    return request && request.timantirecall_pre && data==request.timantirecall_data &&
        timantirecall_silentObject(request.timantirecall_service,"grapHBData",NO)==data &&
        timantirecall_silentSlot(request.timantirecall_service,"preGrapHBCallback",NULL)==request.timantirecall_pre &&
        timantirecall_silentDataMatches(request,data);
}
static BOOL timantirecall_silentState(id result,NSString *state) {
    if(![result isKindOfClass:NSDictionary.class])return NO;
    id value=result[@"state"];
    if([value isKindOfClass:NSNumber.class])value=[value stringValue];
    return [value isKindOfClass:NSString.class] && [value isEqualToString:state];
}
static void timantirecall_silentPoll(void) {
    TIMAntiRecallSilentPacket *request=timantirecall_silent;
    if(!request)return;
    // Only an already-completed, never-submitted pre-open may be retired here.
    // Never clear an outstanding claim or another caller's callback.
    if(request.timantirecall_preResolved && !request.timantirecall_submitted &&
       request.timantirecall_callback && timantirecall_silentOwns(request,request.timantirecall_data)) {
        BOOL known=NO;
        id claim=timantirecall_silentSlot(request.timantirecall_service,"grapHBCallback",&known);
        if(known && !claim && !object_getIvar(request.timantirecall_wallet,timantirecall_silentLowSlot)) {
            const char *args[]={"@",":","@?"};
            IMP setter=timantirecall_silentMethod(object_getClass(request.timantirecall_service),"setPreGrapHBCallback:",NO,"v",3,args);
            if(setter)((void(*)(id,SEL,TIMAntiRecallSilentReceipt))setter)(request.timantirecall_service,sel_registerName("setPreGrapHBCallback:"),nil);
        }
    }
    if(!request.timantirecall_callback || !timantirecall_silentIdle(request.timantirecall_service,request.timantirecall_wallet))return;
    timantirecall_silent=nil;
    NSString *phase=request.timantirecall_phase?:@"redpack-silent-unknown";
    NSString *text=request.timantirecall_valid()?request.timantirecall_text:nil;
    void (^notify)(NSString *,NSString *)=request.timantirecall_finished;
    dispatch_async(dispatch_get_main_queue(),^{
        dispatch_block_t manual=timantirecall_silentManual;timantirecall_silentManual=nil;
        if(manual)manual();
        notify(phase,text);
    });
}
static NSError *timantirecall_silentError(void) {
    return [NSError errorWithDomain:@"com.minis.timantirecall.native-route" code:1 userInfo:nil];
}
static void timantirecall_silentStart(id wallet,SEL selector,id root,id params,TIMAntiRecallSilentReceipt completion) {
    TIMAntiRecallSilentStartIMP original=(TIMAntiRecallSilentStartIMP)atomic_load(&timantirecall_silentStartOriginal);
    TIMAntiRecallSilentPacket *request=NSThread.isMainThread?timantirecall_silent:nil;
    if(request && !request.timantirecall_entering && wallet==request.timantirecall_wallet) {
        // The invisible auto flow must not let a manual open steal its single native callback slots.
        if(!timantirecall_silentManual) {
            NSString *owner=timantirecall_currentAccount();id nativeService=request.timantirecall_service;
            timantirecall_silentManual=^{
                if(owner.length && [owner isEqual:timantirecall_currentAccount()] &&
                   UIApplication.sharedApplication.applicationState==UIApplicationStateActive &&
                   timantirecall_silentIdle(nativeService,wallet))original(wallet,selector,root,params,completion);
                else if(completion)completion(nil,timantirecall_silentError());
            };
        } else if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(nil,timantirecall_silentError());});
        timantirecall_silentPoll();return;
    }
    if(!request || !request.timantirecall_entering || wallet!=request.timantirecall_wallet) {
        original(wallet,selector,root,params,completion);return;
    }
    const char *args[]={"@",":","@"};Class cls=objc_getClass("QQWalletGrapHBService");
    IMP modern=timantirecall_silentMethod(cls,"isGotoNewGrapProcess:",YES,"B",3,args);
    IMP pre=timantirecall_silentMethod(cls,"isNeedGotoPreGrapProcess:",YES,"B",3,args);
    // grabHB: receives the native outer envelope. Native createHBAIODataWithParam:
    // extracts extra_data first; the bill is not a field of the outer dictionary.
    id extra=[params isKindOfClass:NSDictionary.class]?params[@"extra_data"]:nil;
    id bill=[extra isKindOfClass:NSDictionary.class]?extra[@"listid"]:nil;
    NSString *rejection=nil;
    if(!request.timantirecall_valid())rejection=@"redpack-silent-reject-context";
    else if(![extra isKindOfClass:NSDictionary.class])rejection=@"redpack-silent-reject-envelope";
    else if(![bill isKindOfClass:NSString.class])rejection=@"redpack-silent-reject-bill-type";
    else if(![bill isEqualToString:request.timantirecall_bill])rejection=@"redpack-silent-reject-bill-mismatch";
    else if(!modern || !pre)rejection=@"redpack-silent-reject-native-abi";
    else if(!((BOOL(*)(id,SEL,id))modern)(cls,sel_registerName("isGotoNewGrapProcess:"),params))rejection=@"redpack-silent-reject-legacy-route";
    else if(!((BOOL(*)(id,SEL,id))pre)(cls,sel_registerName("isNeedGotoPreGrapProcess:"),params))rejection=@"redpack-silent-reject-no-preopen";
    if(rejection) {
        request.timantirecall_phase=rejection;
        // Fail closed without changing the original envelope, native checks or tokens.
        if(completion)completion(nil,timantirecall_silentError());return;
    }
    request.timantirecall_starting=YES;
    timantirecall_traceEvent(@"redpack-silent-native-start-forwarded");
    @try {original(wallet,selector,root,params,completion);}
    @finally {request.timantirecall_starting=NO;}
    if(!request.timantirecall_pre) {
        id data=timantirecall_silentObject(request.timantirecall_service,"grapHBData",NO);
        if(timantirecall_silentDataMatches(request,data)) {
            request.timantirecall_data=data;
            request.timantirecall_pre=timantirecall_silentSlot(request.timantirecall_service,"preGrapHBCallback",NULL);
        }
    }
}
static void timantirecall_silentLoading(id service,SEL selector) {
    TIMAntiRecallSilentPacket *request=NSThread.isMainThread?timantirecall_silent:nil;
    if(request && service==request.timantirecall_service && request.timantirecall_starting &&
       timantirecall_silentDataMatches(request,timantirecall_silentObject(service,"grapHBData",NO)))return;
    ((TIMAntiRecallSilentVoidIMP)atomic_load(&timantirecall_silentLoadingOriginal))(service,selector);
}
static void timantirecall_silentView(id manager,SEL selector,id controller) {
    TIMAntiRecallSilentViewIMP original=(TIMAntiRecallSilentViewIMP)atomic_load(&timantirecall_silentViewOriginal);
    TIMAntiRecallSilentPacket *request=NSThread.isMainThread?timantirecall_silent:nil;
    if(!request || object_getClass(controller)!=objc_getClass("QQWalletPreGrapHBResultViewController")) {
        original(manager,selector,controller);return;
    }
    id data=timantirecall_silentObject(controller,"grapHBData",NO);
    if(request.timantirecall_starting && !request.timantirecall_pre && timantirecall_silentDataMatches(request,data)) {
        request.timantirecall_data=data;
        request.timantirecall_pre=timantirecall_silentSlot(request.timantirecall_service,"preGrapHBCallback",NULL);
    }
    if(!timantirecall_silentOwns(request,data)) {original(manager,selector,controller);return;}
    // This is the actual native pre-open controller, before UIKit presentation.
    // Keep the model, native token, checks and onOpenButtonClick: consumer intact.
    request.timantirecall_preResolved=YES;
    if(request.timantirecall_submitted)return;
    if(!request.timantirecall_valid() || NSProcessInfo.processInfo.systemUptime>=request.timantirecall_deadline ||
       !timantirecall_silentState(timantirecall_silentObject(data,"grapResultData",NO),@"16")) {
        request.timantirecall_callback=YES;request.timantirecall_phase=@"redpack-silent-preopen-cancelled";
        dispatch_async(dispatch_get_main_queue(),^{timantirecall_silentPoll();});return;
    }
    request.timantirecall_controller=controller;
    objc_setAssociatedObject(controller,&timantirecall_silentControllerKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [(UIViewController *)controller loadViewIfNeeded];
    id view=timantirecall_silentObject(controller,"grapHBView",NO);
    const char *args[]={"@",":","@"};
    IMP action=timantirecall_silentMethod(object_getClass(controller),"onOpenButtonClick:",NO,"v",3,args);
    if(!action || object_getClass(view)!=objc_getClass("QQWalletPreOpenHBView") ||
       timantirecall_silentObject(view,"grapHBData",NO)!=data || ((UIViewController *)controller).view.window) {
        request.timantirecall_callback=YES;request.timantirecall_phase=@"redpack-silent-unresolved-view";
        dispatch_async(dispatch_get_main_queue(),^{timantirecall_silentPoll();});return;
    }
    request.timantirecall_submitted=YES;
    timantirecall_traceEvent(@"redpack-silent-popup-suppressed");
    ((void(*)(id,SEL,id))action)(controller,sel_registerName("onOpenButtonClick:"),view);
}
static void timantirecall_silentDismiss(id controller,SEL selector,BOOL animated,void (^completion)(void)) {
    BOOL details=NO;
    if(NSThread.isMainThread && objc_getAssociatedObject(controller,&timantirecall_silentControllerKey)) {
#ifdef TIMANTIRECALL_UI_TEST
        extern void (^const timantirecall_fixtureDetails)(void);
        details=completion && completion==timantirecall_fixtureDetails;
#else
        details=completion && (uintptr_t)(__bridge const void *)completion==(uintptr_t)timantirecall_silentImage+0xc00158u;
#endif
    }
    // Preserve native UIKit forwarding, but do not start details from an unpresented auto controller.
    ((TIMAntiRecallSilentDismissIMP)atomic_load(&timantirecall_silentDismissOriginal))(controller,selector,animated,details?nil:completion);
}
static BOOL timantirecall_installSilent(Class service) {
    if(timantirecall_silentImageClass)return service==timantirecall_silentImageClass;
    Method entry=class_getClassMethod(service,sel_registerName("grabRedPackWithMsgRecord:rootVC:completion:"));
    Dl_info image={0};
    if(!entry || !dladdr((const void *)method_getImplementation(entry),&image) || !image.dli_fbase)return NO;
    timantirecall_silentImage=image.dli_fbase;
    Class wallet=objc_getClass("QQWallet"),nativeService=objc_getClass("QQWalletGrapHBService");
    Class manager=objc_getClass("QQWalletSceneManager"),controller=objc_getClass("QQWalletPreGrapHBResultViewController");
    if(!controller || ![controller isSubclassOfClass:UIViewController.class])return NO;
    const char *objects[]={"@",":","@","@","@?"},*one[]={"@",":","@"},*zero[]={"@",":"};
    const char *dismiss[]={"@",":","B","@?"};
    IMP start=timantirecall_silentMethod(wallet,"grabHB:params:completion:",NO,"v",5,objects);
    IMP show=timantirecall_silentMethod(manager,"presentTransparentViewController:",YES,"v",3,one);
    IMP loading=timantirecall_silentMethod(nativeService,"showLoading",NO,"v",2,zero);
    if(!start || !show || !loading ||
       !timantirecall_silentMethod(controller,"onOpenButtonClick:",NO,"v",3,one) ||
       !timantirecall_silentMethod(controller,"handleHBGrapResult:",NO,"v",3,one) ||
       !timantirecall_silentMethod(nativeService,"isGotoNewGrapProcess:",YES,"B",3,one) ||
       !timantirecall_silentMethod(nativeService,"isNeedGotoPreGrapProcess:",YES,"B",3,one) ||
       !timantirecall_silentMethod(wallet,"isPaying",NO,"B",2,zero))return NO;
    Ivar low=class_getInstanceVariable(wallet,"_grabCompletionBlock");
    if(!low || strcmp(ivar_getTypeEncoding(low),"@?") || ivar_getOffset(low)!=0x30 || class_getInstanceSize(wallet)<0x38)return NO;
    Method inherited=class_getInstanceMethod(controller,@selector(dismissViewControllerAnimated:completion:));
    if(!timantirecall_methodTypes(inherited,"v",4,dismiss))return NO;
    atomic_store(&timantirecall_silentDismissOriginal,method_getImplementation(inherited));
    if(!class_addMethod(controller,@selector(dismissViewControllerAnimated:completion:),(IMP)timantirecall_silentDismiss,method_getTypeEncoding(inherited)))return NO;
    atomic_store(&timantirecall_silentStartOriginal,start);atomic_store(&timantirecall_silentViewOriginal,show);
    atomic_store(&timantirecall_silentLoadingOriginal,loading);
    method_setImplementation(class_getInstanceMethod(wallet,sel_registerName("grabHB:params:completion:")),(IMP)timantirecall_silentStart);
    method_setImplementation(class_getClassMethod(manager,sel_registerName("presentTransparentViewController:")),(IMP)timantirecall_silentView);
    method_setImplementation(class_getInstanceMethod(nativeService,sel_registerName("showLoading")),(IMP)timantirecall_silentLoading);
    timantirecall_silentLowSlot=low;timantirecall_silentImageClass=service;return YES;
}
BOOL timantirecall_silentPacketReady(Class service) {
    if(!NSThread.isMainThread)return NO;
    timantirecall_silentPoll();
    if(timantirecall_silent || timantirecall_silentManual || !timantirecall_walletCanAcceptPacket(service) || !timantirecall_installSilent(service))return NO;
    id wallet=timantirecall_silentObject(objc_getClass("QQWallet"),"GetInstance",YES);
    id nativeService=timantirecall_silentObject(objc_getClass("QQWalletGrapHBService"),"shareInstance",YES);
    return object_getClass(wallet)==objc_getClass("QQWallet") && object_getClass(nativeService)==objc_getClass("QQWalletGrapHBService") &&
        timantirecall_silentIdle(nativeService,wallet);
}
static void timantirecall_silentWaitExpired(TIMAntiRecallSilentPacket *request) {
    if(!request || request!=timantirecall_silent)return;
    if(!request.timantirecall_callback) {
        timantirecall_traceEvent(@"redpack-silent-wait-expired");
        // Waiting expired is not a final network response. A submitted native
        // claim keeps its callback consumer alive so a late receipt is not lost.
        if(!request.timantirecall_submitted && request.timantirecall_preResolved) {
            request.timantirecall_callback=YES;request.timantirecall_phase=@"redpack-silent-preopen-expired";
        }
    }
    timantirecall_silentPoll();
}
#ifdef TIMANTIRECALL_UI_TEST
void timantirecall_expireSilentFixture(void) {timantirecall_silentWaitExpired(timantirecall_silent);}
#endif
BOOL timantirecall_beginSilentPacket(Class service,NSString *bill,BOOL (^valid)(void),void (^finished)(NSString *,NSString *),void (^invoke)(TIMAntiRecallSilentReceipt)) {
    if(!NSThread.isMainThread || !bill.length || bill.length>128 || !valid || !finished || !invoke || !valid() ||
       !timantirecall_silentPacketReady(service))return NO;
    TIMAntiRecallSilentPacket *request=[TIMAntiRecallSilentPacket new];
    request.timantirecall_bill=[bill copy];request.timantirecall_valid=[valid copy];request.timantirecall_finished=[finished copy];
    request.timantirecall_wallet=timantirecall_silentObject(objc_getClass("QQWallet"),"GetInstance",YES);
    request.timantirecall_service=timantirecall_silentObject(objc_getClass("QQWalletGrapHBService"),"shareInstance",YES);
    request.timantirecall_deadline=NSProcessInfo.processInfo.systemUptime+30;
    timantirecall_silent=request;request.timantirecall_entering=YES;
    __weak TIMAntiRecallSilentPacket *weakRequest=request;
    TIMAntiRecallSilentReceipt completion=^(NSDictionary *result,NSError *error) {
        // The native response stack still owns its callback slots here. Resume on the next turn.
        dispatch_async(dispatch_get_main_queue(),^{
            TIMAntiRecallSilentPacket *live=weakRequest;
            if(!live || live!=timantirecall_silent || live.timantirecall_callback)return;
            live.timantirecall_callback=YES;
            live.timantirecall_phase=error?(live.timantirecall_phase?:@"redpack-silent-native-error"):@"redpack-silent-unknown";
            if(error && ![error.domain isEqualToString:@"com.minis.timantirecall.native-route"])
                timantirecall_traceEvent([NSString stringWithFormat:@"redpack-silent-wallet-error-code-%lld",(long long)error.code]);
            id current=timantirecall_silentObject(live.timantirecall_service,"grapHBData",NO);
            if(!error && live.timantirecall_submitted && live.timantirecall_valid() && current==live.timantirecall_data &&
               timantirecall_silentDataMatches(live,current) && timantirecall_silentState(result,@"0")) {
                id received=[result isKindOfClass:NSDictionary.class]?result[@"recv_object"]:nil;
                if([received isKindOfClass:NSDictionary.class])live.timantirecall_text=timantirecall_packetAmountText(received[@"amount"]);
                if(live.timantirecall_text)live.timantirecall_phase=@"redpack-silent-receipt-confirmed";
            }
            timantirecall_silentPoll();
        });
    };
    @try {invoke(completion);}
    @catch(__unused NSException *exception) {
        request.timantirecall_callback=YES;request.timantirecall_phase=@"redpack-silent-route-exception";
    }
    @finally {request.timantirecall_entering=NO;}
    timantirecall_silentPoll();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        timantirecall_silentWaitExpired(weakRequest);
    });
    return YES;
}
#endif
