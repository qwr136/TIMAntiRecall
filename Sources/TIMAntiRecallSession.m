#import "TIMAntiRecallMarks.h"
#include <stdatomic.h>
#include <stdlib.h>

static char timantirecall_ownerKey;
static _Atomic(IMP) timantirecall_sessionInitOriginal;
static _Atomic(IMP) timantirecall_sessionCloseOriginal;
static Class timantirecall_sessionClass;

NSString *timantirecall_sessionOwner(id session) {
    id owner=objc_getAssociatedObject(session,&timantirecall_ownerKey);
    return [owner isKindOfClass:NSString.class]?[owner copy]:nil;
}
// Target evidence: init:depends:dispatcherDepends:listener: v48@0:8@16@24@32@40.
// Config is OCInitSessionConfig; selfUid getter is @16@0:8. Never access auth fields.
static void timantirecall_sessionInit(id receiver,SEL selector,id config,id depends,id dispatcher,id listener) {
    Class cfg=objc_getClass("OCInitSessionConfig");
    const char *args[]={"@",":"};SEL uid=sel_registerName("selfUid");
    NSString *owner=nil;
    if(cfg && [config isKindOfClass:cfg] && timantirecall_methodTypes(class_getInstanceMethod(object_getClass(config),uid),"@",2,args)) {
        id candidate=((id(*)(id,SEL))[config methodForSelector:uid])(config,uid);
        if([candidate isKindOfClass:NSString.class] && [candidate length]>0 && [candidate length]<=128)owner=[candidate copy];
    }
    objc_setAssociatedObject(receiver,&timantirecall_ownerKey,owner,OBJC_ASSOCIATION_COPY);
    IMP original=atomic_load_explicit(&timantirecall_sessionInitOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL,id,id,id,id))original)(receiver,selector,config,depends,dispatcher,listener);
}
static void timantirecall_sessionClose(id receiver,SEL selector,id callback) {
    objc_setAssociatedObject(receiver,&timantirecall_ownerKey,nil,OBJC_ASSOCIATION_COPY);
    IMP original=atomic_load_explicit(&timantirecall_sessionCloseOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL,id))original)(receiver,selector,callback);
}
static Method timantirecall_sessionOwn(Class cls,SEL sel) {
    unsigned count=0;Method found=NULL;Method *methods=class_copyMethodList(cls,&count);
    for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==sel){found=methods[i];break;}
    free(methods);return found;
}
void timantirecall_installSessionTracking(Class target) {
    if(!target)return;
    @synchronized(NSObject.class) {
        if(timantirecall_sessionClass)return;
        Method init=timantirecall_sessionOwn(target,sel_registerName("init:depends:dispatcherDepends:listener:"));
        Method close=timantirecall_sessionOwn(target,sel_registerName("close:"));
        const char *initArgs[]={"@",":","@","@","@","@"};const char *closeArgs[]={"@",":","@"};
        if(!timantirecall_methodTypes(init,"v",6,initArgs)||!timantirecall_methodTypes(close,"v",3,closeArgs))return;
        IMP initIMP=method_getImplementation(init),closeIMP=method_getImplementation(close);
        if(!initIMP || !closeIMP)return;
        atomic_store_explicit(&timantirecall_sessionInitOriginal,initIMP,memory_order_release);
        atomic_store_explicit(&timantirecall_sessionCloseOriginal,closeIMP,memory_order_release);
        method_setImplementation(init,(IMP)timantirecall_sessionInit);
        method_setImplementation(close,(IMP)timantirecall_sessionClose);
        timantirecall_sessionClass=target;
    }
}
