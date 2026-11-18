#import "TIMAntiRecallColdSync.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallBootstrap.h"
#include <stdatomic.h>
#include <stdlib.h>

static _Atomic(IMP) timantirecall_coldRecallOriginal;
static Class timantirecall_coldRecallClass;
static void timantirecall_setRecallTime(id receiver,SEL selector,int64_t value) {
    // This is the narrow cold-start boundary. Realtime recall is already
    // blocked before the kernel. Only a persisted exact identity is protected.
    if(value>0) {
        NSString *owner=timantirecall_currentAccount();
        NSDictionary *identity=timantirecall_recordIdentity(receiver,owner);
        if(identity && [timantirecall_sharedMarks() timantirecall_containsIdentity:identity]) {
            timantirecall_bootstrapEvent("cold-recall-protected");
            return;
        }
    }
    IMP original=atomic_load_explicit(&timantirecall_coldRecallOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL,int64_t))original)(receiver,selector,value);
}
static Method timantirecall_coldOwn(Class cls,SEL selector) {
    unsigned count=0;Method found=NULL;Method *methods=class_copyMethodList(cls,&count);
    for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==selector){found=methods[i];break;}
    free(methods);return found;
}
BOOL timantirecall_installColdRecallProtection(void) {
    @synchronized(NSObject.class) {
        if(timantirecall_coldRecallClass)return YES;
        Class cls=objc_getClass("OCMsgRecord");SEL selector=sel_registerName("setRecallTime:");
        const char *args[]={"@",":","q"};Method method=timantirecall_coldOwn(cls,selector);
        if(!cls||!timantirecall_methodTypes(method,"v",3,args))return NO;
        IMP original=method_getImplementation(method);if(!original)return NO;
        atomic_store_explicit(&timantirecall_coldRecallOriginal,original,memory_order_release);
        method_setImplementation(method,(IMP)timantirecall_setRecallTime);
        timantirecall_coldRecallClass=cls;
        timantirecall_bootstrapEvent("cold-recall-setter-installed");
        return YES;
    }
}
