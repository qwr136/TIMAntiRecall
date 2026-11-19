#import "TIMAntiRecallPacketWallet.h"
#ifdef TIMANTIRECALL_NATIVE_TEST
BOOL timantirecall_walletCanAcceptPacket(Class service) {(void)service;return NO;}
BOOL timantirecall_installPacketFinish(Class service) {(void)service;return NO;}
BOOL timantirecall_walletPopupCanRetire(id view) {(void)view;return NO;}
BOOL timantirecall_walletPopupMatchesBill(id view,NSString *bill) {(void)view;(void)bill;return NO;}
void timantirecall_armPacketFinish(id view, NSString *bill, BOOL (^valid)(void), void (^closed)(void)) {(void)view;(void)bill;(void)valid;(void)closed;}
void timantirecall_disarmPacketFinish(void) {}
#else
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallTrace.h"
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <mach-o/loader.h>
#include <mach/machine.h>
#include <math.h>
#include <stdatomic.h>
#include <string.h>

static Class timantirecall_walletImageClass;
static const void *timantirecall_walletImageBase;
static BOOL timantirecall_walletImageReady(Class service) {
    if(!service)return NO;
    if(service==timantirecall_walletImageClass)return YES;
#ifdef TIMANTIRECALL_UI_TEST
    timantirecall_walletImageClass=service;return YES;
#else
    Method entry=class_getClassMethod(service,sel_registerName("grabRedPackWithMsgRecord:rootVC:completion:"));
    Dl_info image={0};
    if(!entry || !dladdr((const void *)method_getImplementation(entry),&image) || !image.dli_fbase)return NO;
    const struct mach_header_64 *header=image.dli_fbase;
    if(header->magic!=MH_MAGIC_64 || header->filetype!=MH_DYLIB || header->cputype!=CPU_TYPE_ARM64 ||
       (header->cpusubtype & ~CPU_SUBTYPE_MASK)!=CPU_SUBTYPE_ARM64_ALL ||
       header->sizeofcmds>1048576 || header->ncmds>header->sizeofcmds/sizeof(struct load_command))return NO;
    const uint8_t expected[]={0xe1,0xd2,0x71,0xfd,0x49,0x14,0x3f,0xd9,0x9f,0x85,0x2c,0x28,0x1f,0x8b,0x81,0x47};
    const uint8_t *cursor=(const uint8_t *)(header+1),*end=cursor+header->sizeofcmds;
    BOOL matched=NO;
    for(uint32_t i=0;i<header->ncmds;i++) {
        if((size_t)(end-cursor)<sizeof(struct load_command))return NO;
        const struct load_command *command=(const void *)cursor;
        if(command->cmdsize<sizeof(*command) || command->cmdsize%8 || command->cmdsize>(size_t)(end-cursor))return NO;
        if(command->cmd==LC_UUID) {
            if(matched || command->cmdsize!=sizeof(struct uuid_command) || memcmp(((const struct uuid_command *)command)->uuid,expected,16))return NO;
            matched=YES;
        }
        cursor+=command->cmdsize;
    }
    if(!matched || cursor!=end)return NO;
    timantirecall_walletImageBase=image.dli_fbase;timantirecall_walletImageClass=service;return YES;
#endif
}
static BOOL timantirecall_walletOwnsIMP(IMP imp) {
    if(!imp || !timantirecall_walletImageClass)return NO;
#ifdef TIMANTIRECALL_UI_TEST
    (void)timantirecall_walletImageBase;return YES;
#else
    Dl_info image={0};
    return dladdr((const void *)imp,&image) && image.dli_fbase==timantirecall_walletImageBase;
#endif
}
static IMP timantirecall_walletGetter(Method method,const char *type) {
    const char *args[]={"@",":"};
    if(!timantirecall_methodTypes(method,type,2,args))return NULL;
    IMP imp=method_getImplementation(method);
    return timantirecall_walletOwnsIMP(imp)?imp:NULL;
}
static id timantirecall_walletObject(id object,const char *name) {
    if(!object)return nil;
    SEL selector=sel_registerName(name);
    IMP getter=timantirecall_walletGetter(class_getInstanceMethod(object_getClass(object),selector),"@");
    return getter?((id(*)(id,SEL))getter)(object,selector):nil;
}
BOOL timantirecall_walletCanAcceptPacket(Class service) {
    if(!NSThread.isMainThread || !timantirecall_walletImageReady(service))return NO;
    Class cls=objc_getClass("QQWalletGrapHBService");
    SEL shared=sel_registerName("shareInstance"),pre=sel_registerName("preGrapHBCallback"),claim=sel_registerName("grapHBCallback");
    IMP acquire=timantirecall_walletGetter(class_getClassMethod(cls,shared),"@");
    IMP preSlot=timantirecall_walletGetter(class_getInstanceMethod(cls,pre),"@?");
    IMP claimSlot=timantirecall_walletGetter(class_getInstanceMethod(cls,claim),"@?");
    if(!acquire || !preSlot || !claimSlot)return NO;
    id instance=((id(*)(id,SEL))acquire)(cls,shared);
    if(object_getClass(instance)!=cls)return NO;
    // Only inspect whether the native slots are occupied; never invoke or clear them.
    typedef void (^TIMAntiRecallWalletSlot)(void);
    typedef TIMAntiRecallWalletSlot (*TIMAntiRecallWalletSlotGetter)(id,SEL);
    return !((TIMAntiRecallWalletSlotGetter)preSlot)(instance,pre) && !((TIMAntiRecallWalletSlotGetter)claimSlot)(instance,claim);
}

static _Atomic(IMP) timantirecall_dismissOriginal;
static Class timantirecall_dismissClass;
static __weak id timantirecall_finishView;
static NSString *timantirecall_finishBill;
static BOOL (^timantirecall_finishValid)(void);
static void (^timantirecall_finishClosed)(void);
void timantirecall_disarmPacketFinish(void) {
    if(!NSThread.isMainThread)return;
    timantirecall_finishView=nil;timantirecall_finishBill=nil;
    timantirecall_finishValid=nil;timantirecall_finishClosed=nil;
}
void timantirecall_armPacketFinish(id view,NSString *bill,BOOL (^valid)(void),void (^closed)(void)) {
    if(!NSThread.isMainThread || !timantirecall_dismissClass || !valid || !closed || !bill.length || bill.length>128 ||
       object_getClass(view)!=objc_getClass("QQWalletPreOpenHBView"))return;
    timantirecall_finishView=view;timantirecall_finishBill=[bill copy];
    timantirecall_finishValid=[valid copy];timantirecall_finishClosed=[closed copy];
}

static BOOL timantirecall_walletNumber(id value,double *out) {
    if([value isKindOfClass:NSNumber.class]) {*out=[value doubleValue];return isfinite(*out);}
    if(![value isKindOfClass:NSString.class] || ![value length] || [value length]>64)return NO;
    NSScanner *scanner=[NSScanner scannerWithString:value];
    scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return [scanner scanDouble:out] && scanner.isAtEnd && isfinite(*out);
}
BOOL timantirecall_walletPopupMatchesBill(id view,NSString *bill) {
    if(!view || object_getClass(view)!=objc_getClass("QQWalletPreOpenHBView") || !bill.length)return NO;
    id data=timantirecall_walletObject(view,"grapHBData");
    if(!data || object_getClass(data)!=objc_getClass("QQWalletGrapHBData"))return NO;
    id aio=timantirecall_walletObject(data,"aioData");
    if(!aio || object_getClass(aio)!=objc_getClass("QQWalletGrapHBAIOData"))return NO;
    id actual=timantirecall_walletObject(aio,"listId");
    return [actual isKindOfClass:NSString.class] && [actual isEqual:bill];
}
BOOL timantirecall_walletPopupCanRetire(id view) {
    if(!view || object_getClass(view)!=objc_getClass("QQWalletPreOpenHBView"))return NO;
    SEL animation=sel_registerName("grapHBAnimationBlock");
    IMP getter=timantirecall_walletGetter(class_getInstanceMethod(object_getClass(view),animation),"@?");
    typedef void (^TIMAntiRecallAnimation)(BOOL);
    typedef TIMAntiRecallAnimation (*TIMAntiRecallAnimationGetter)(id,SEL);
    if(!getter || ((TIMAntiRecallAnimationGetter)getter)(view,animation))return NO;
    id data=timantirecall_walletObject(view,"grapHBData");
    if(!data || object_getClass(data)!=objc_getClass("QQWalletGrapHBData"))return NO;
    SEL response=sel_registerName("grapResultData");
    IMP read=timantirecall_walletGetter(class_getInstanceMethod(object_getClass(data),response),"@");
    if(!read)return NO;
    id result=((id(*)(id,SEL))read)(data,response);
    if(!result)return YES;
    if(![result isKindOfClass:NSDictionary.class])return NO;
    double state=0,amount=0;
    if(!timantirecall_walletNumber(result[@"state"],&state))return YES;
    // Preserve real-name verification and native positive-result animation.
    if(state==5)return NO;
    id received=result[@"recv_object"];
    return state!=0 || ![received isKindOfClass:NSDictionary.class] ||
           !timantirecall_walletNumber(received[@"amount"],&amount) || amount<=0;
}
static BOOL timantirecall_walletSameSuccessfulPopup(id controller) {
    id view=timantirecall_finishView;
    if(!view || object_getClass(controller)!=timantirecall_dismissClass ||
       timantirecall_walletObject(controller,"grapHBView")!=view ||
       !timantirecall_finishValid || !timantirecall_finishValid())return NO;
    id data=timantirecall_walletObject(controller,"grapHBData");
    if(object_getClass(data)!=objc_getClass("QQWalletGrapHBData") || !data)return NO;
    id aio=timantirecall_walletObject(data,"aioData");
    if(object_getClass(aio)!=objc_getClass("QQWalletGrapHBAIOData") || !aio)return NO;
    id bill=timantirecall_walletObject(aio,"listId");
    if(![bill isKindOfClass:NSString.class] || ![bill isEqual:timantirecall_finishBill])return NO;
    id result=timantirecall_walletObject(data,"grapResultData");
    if(![result isKindOfClass:NSDictionary.class])return NO;
    id received=result[@"recv_object"];double state,amount;
    return timantirecall_walletNumber(result[@"state"],&state) && state==0 &&
           [received isKindOfClass:NSDictionary.class] && timantirecall_walletNumber(received[@"amount"],&amount) && amount>0;
}
static BOOL timantirecall_walletDetailContinuation(void (^completion)(void)) {
    if(!completion)return NO;
#ifdef TIMANTIRECALL_UI_TEST
    extern void (^const timantirecall_fixtureDetails)(void);
    return completion==timantirecall_fixtureDetails;
#else
    // Global no-capture Block passed at 0x568a6c. Its invoke (0x568a80)
    // only opens details. Compare object identity, never parse/call a raw pointer.
    return (uintptr_t)(__bridge const void *)completion==(uintptr_t)timantirecall_walletImageBase+0xc00158u;
#endif
}
typedef void (*TIMAntiRecallWalletDismissIMP)(id,SEL,BOOL,void (^)(void));
static void timantirecall_popupDismiss(id controller,SEL selector,BOOL animated,void (^completion)(void)) {
    TIMAntiRecallWalletDismissIMP original=(TIMAntiRecallWalletDismissIMP)atomic_load(&timantirecall_dismissOriginal);
    void (^notify)(void)=nil;
    @try {
        if(NSThread.isMainThread && !animated && timantirecall_finishClosed && timantirecall_walletDetailContinuation(completion) &&
           timantirecall_walletSameSuccessfulPopup(controller)) {
            notify=timantirecall_finishClosed;timantirecall_disarmPacketFinish();
            timantirecall_traceEvent(@"redpack-native-detail-skipped");
        }
    } @catch(__unused NSException *exception) {}
    // The original UIKit dismissal and its lifecycle run once in either case.
    original(controller,selector,animated,notify?:completion);
}
BOOL timantirecall_installPacketFinish(Class service) {
    if(!NSThread.isMainThread || !timantirecall_walletImageReady(service))return NO;
    if(timantirecall_dismissClass)return YES;
    Class cls=objc_getClass("QQWalletPreGrapHBResultViewController");
    if(!cls || ![cls isSubclassOfClass:UIViewController.class])return NO;
    Method identity=class_getInstanceMethod(cls,sel_registerName("handleHBGrapResult:"));
    const char *response[]={"@",":","@"};
    if(!timantirecall_methodTypes(identity,"v",3,response) || !timantirecall_walletOwnsIMP(method_getImplementation(identity)))return NO;
    SEL selector=@selector(dismissViewControllerAnimated:completion:);
    Method inherited=class_getInstanceMethod(cls,selector);
    const char *dismiss[]={"@",":","B","@?"};
    if(!timantirecall_methodTypes(inherited,"v",4,dismiss))return NO;
    IMP original=method_getImplementation(inherited);
    if(!original || original==(IMP)timantirecall_popupDismiss)return NO;
    atomic_store(&timantirecall_dismissOriginal,original);
    // Add an override to the one audited subclass; never replace UIViewController.
    if(!class_addMethod(cls,selector,(IMP)timantirecall_popupDismiss,method_getTypeEncoding(inherited)))return NO;
    timantirecall_dismissClass=cls;return YES;
}
#endif
