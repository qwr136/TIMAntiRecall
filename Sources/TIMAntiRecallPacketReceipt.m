#import "TIMAntiRecallPacketReceipt.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallTrace.h"
#include <objc/runtime.h>
#include <dlfcn.h>
#include <mach-o/loader.h>
#include <stdatomic.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
BOOL timantirecall_walletTrustedClass(Class cls) {
    if(!cls)return NO;
#ifdef TIMANTIRECALL_UI_TEST
    return YES; // UIKit fixture executable, never enabled for production library.
#else
    const char *path=class_getImageName(cls);Dl_info image={0};
    Class service=objc_getClass("QQWalletRedPacketMsgService");
    Method entry=class_getClassMethod(service,sel_registerName("grabRedPackWithMsgRecord:rootVC:completion:"));
    if(!path || !service || !entry || !class_getImageName(service) || strcmp(path,class_getImageName(service)) ||
       !dladdr((const void *)method_getImplementation(entry),&image) || !image.dli_fbase)return NO;
    const struct mach_header_64 *header=image.dli_fbase;
    if(header->magic!=MH_MAGIC_64 || header->filetype!=MH_DYLIB || header->ncmds>4096 || header->sizeofcmds>1048576)return NO;
    const uint8_t expected[]={0xe1,0xd2,0x71,0xfd,0x49,0x14,0x3f,0xd9,0x9f,0x85,0x2c,0x28,0x1f,0x8b,0x81,0x47};
    const uint8_t *cursor=(const uint8_t *)(header+1),*end=cursor+header->sizeofcmds;
    BOOL found=NO;
    for(uint32_t i=0;i<header->ncmds;i++) {
        if((size_t)(end-cursor)<sizeof(struct load_command))return NO;
        const struct load_command *command=(const void *)cursor;
        if(command->cmdsize<sizeof(*command) || command->cmdsize>(size_t)(end-cursor))return NO;
        if(command->cmd==LC_UUID) {
            if(found || command->cmdsize!=sizeof(struct uuid_command) || memcmp(((const struct uuid_command *)command)->uuid,expected,16))return NO;
            found=YES;
        }
        cursor+=command->cmdsize;
    }
    return found && cursor==end;
#endif
}
@interface TIMAntiRecallPacketReceipt ()
@property(nonatomic,copy) NSString *timantirecall_bill;
@property(nonatomic) BOOL timantirecall_ok, timantirecall_error;
@end
static __weak TIMAntiRecallPacketReceipt *timantirecall_activeReceipt;
static _Atomic(IMP) timantirecall_receiptOriginal;
static id timantirecall_receiptObject(id object,const char *name,Class required) {
    if(!object || !required || ![object isKindOfClass:required] || !timantirecall_walletTrustedClass(object_getClass(object)))return nil;
    SEL selector=sel_registerName(name);Method method=class_getInstanceMethod(object_getClass(object),selector);
    const char *args[]={"@",":"};
    if(!timantirecall_methodTypes(method,"@",2,args))return nil;
    return ((id(*)(id,SEL))method_getImplementation(method))(object,selector);
}
static BOOL timantirecall_receiptNumber(id value,double *out) {
    if([value isKindOfClass:NSNumber.class]) {*out=[value doubleValue];return isfinite(*out);}
    if(![value isKindOfClass:NSString.class] || [value length]>64 || ![value length])return NO;
    NSScanner *scanner=[NSScanner scannerWithString:value];scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return [scanner scanDouble:out] && scanner.isAtEnd && isfinite(*out);
}
static void timantirecall_receiptHandle(id controller,SEL selector,id result) {
    IMP original=atomic_load(&timantirecall_receiptOriginal);
    TIMAntiRecallPacketReceipt *receipt=NSThread.isMainThread?timantirecall_activeReceipt:nil;
    BOOL matches=NO;
    @try {
        id data=timantirecall_receiptObject(controller,"grapHBData",objc_getClass("QQWalletPreGrapHBResultViewController"));
        id aio=timantirecall_receiptObject(data,"aioData",objc_getClass("QQWalletGrapHBData"));
        id bill=timantirecall_receiptObject(aio,"listId",objc_getClass("QQWalletGrapHBAIOData"));
        matches=receipt && [bill isKindOfClass:NSString.class] && [bill isEqual:receipt.timantirecall_bill];
    }@catch(__unused NSException *exception) {}
    // Original native UI consumer is never skipped, rerouted or invoked twice.
    ((void(*)(id,SEL,id))original)(controller,selector,result);
    if(!matches || receipt!=timantirecall_activeReceipt || ![result isKindOfClass:NSDictionary.class])return;
    @try {
        double state=0,amount=0;
        if(!timantirecall_receiptNumber(result[@"state"],&state) || floor(state)!=state)return;
        if(state!=0) {
            receipt.timantirecall_error=YES;timantirecall_traceEvent(@"redpack-native-receipt-negative");return;
        }
        id received=result[@"recv_object"];
        if([received isKindOfClass:NSDictionary.class] && timantirecall_receiptNumber(received[@"amount"],&amount) && amount>0) {
            receipt.timantirecall_ok=YES;timantirecall_traceEvent(@"redpack-native-receipt-confirmed");
        }
    }@catch(__unused NSException *exception) {}
}
static BOOL timantirecall_installReceiptObserver(void) {
    if(atomic_load(&timantirecall_receiptOriginal))return YES;
    Class cls=objc_getClass("QQWalletPreGrapHBResultViewController");
    if(!timantirecall_walletTrustedClass(cls))return NO;
    SEL selector=sel_registerName("handleHBGrapResult:");unsigned count=0;Method selected=NULL;
    Method *methods=class_copyMethodList(cls,&count);
    for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==selector){selected=methods[i];break;}
    free(methods);const char *args[]={"@",":","@"};
    if(!timantirecall_methodTypes(selected,"v",3,args))return NO;
    IMP original=method_getImplementation(selected);if(!original || original==(IMP)timantirecall_receiptHandle)return NO;
    atomic_store(&timantirecall_receiptOriginal,original);method_setImplementation(selected,(IMP)timantirecall_receiptHandle);
    return YES;
}
@implementation TIMAntiRecallPacketReceipt
- (instancetype)initWithBill:(NSString *)bill {
    if((self=[super init])) {
        if(!NSThread.isMainThread || ![bill isKindOfClass:NSString.class] || !bill.length || bill.length>128)return nil;
        self.timantirecall_bill=bill;
        if(timantirecall_installReceiptObserver())timantirecall_activeReceipt=self;
        else timantirecall_traceEvent(@"redpack-native-receipt-observer-unavailable");
    }
    return self;
}
- (BOOL)timantirecall_confirmed {return self.timantirecall_ok && !self.timantirecall_error;}
- (BOOL)timantirecall_failed {return self.timantirecall_error;}
@end
