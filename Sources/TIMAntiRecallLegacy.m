#import "TIMAntiRecallMarks.h"
#include <stdatomic.h>
#include <stdlib.h>

static char timantirecall_legacyIdentityKey;
static _Atomic(IMP) timantirecall_convertOriginal;
static BOOL timantirecall_converterInstalled;

static BOOL timantirecall_legacyGetter(id object,NSString *name,const char *result) {
    const char *args[]={"@",":"};
    return object && timantirecall_methodTypes(class_getInstanceMethod(object_getClass(object),NSSelectorFromString(name)),result,2,args);
}
static id timantirecall_legacyObject(id object,NSString *name) {
    if(!timantirecall_legacyGetter(object,name,"@"))return nil;
    SEL sel=NSSelectorFromString(name);
    return ((id(*)(id,SEL))[object methodForSelector:sel])(object,sel);
}
static NSDictionary *timantirecall_legacyFingerprint(id message) {
    Class cls=objc_getClass("QQMessageModel");
    if(!cls || ![message isKindOfClass:cls] ||
       !timantirecall_legacyGetter(message,@"msgSeq","q") ||
       !timantirecall_legacyGetter(message,@"msgID","i") ||
       !timantirecall_legacyGetter(message,@"msgUid","q"))return nil;
    SEL seq=sel_registerName("msgSeq"),mid=sel_registerName("msgID"),uid=sel_registerName("msgUid");
    int64_t sequence=((int64_t(*)(id,SEL))[message methodForSelector:seq])(message,seq);
    int32_t messageID=((int32_t(*)(id,SEL))[message methodForSelector:mid])(message,mid);
    int64_t randomID=((int64_t(*)(id,SEL))[message methodForSelector:uid])(message,uid);
    id peer=timantirecall_legacyObject(message,@"peerUin");
    id group=timantirecall_legacyObject(message,@"groupCode");
    if(peer && (![peer isKindOfClass:NSString.class] || [peer length]>128))return nil;
    if(group && (![group isKindOfClass:NSString.class] || [group length]>128))return nil;
    return @{@"seq":@(sequence),@"id":@(messageID),@"uid":@(randomID),
             @"peer":[peer copy]?:@"",@"group":[group copy]?:@""};
}
// +recordConvertMessageModel: @24@0:8@16, IMP 0x100224040 in the locked TIM.
// It replaces private msgSeq with clientSeq. Keep the original record identity;
// the legacy fingerprint only detects reuse/mutation and is never a wire key.
static id timantirecall_convertMessage(id receiver,SEL selector,id record) {
    NSString *owner=timantirecall_currentAccount();
    IMP original=atomic_load_explicit(&timantirecall_convertOriginal,memory_order_acquire);
    id result=original?((id(*)(id,SEL,id))original)(receiver,selector,record):nil;
    NSDictionary *identity=timantirecall_recordIdentity(record,owner);
    NSDictionary *fingerprint=timantirecall_legacyFingerprint(result);
    if(identity && fingerprint && [owner isEqual:timantirecall_currentAccount()]) {
        objc_setAssociatedObject(result,&timantirecall_legacyIdentityKey,
            @{@"identity":[identity copy],@"fingerprint":fingerprint},OBJC_ASSOCIATION_RETAIN);
    } else if(result && [result isKindOfClass:objc_getClass("QQMessageModel")]) {
        objc_setAssociatedObject(result,&timantirecall_legacyIdentityKey,nil,OBJC_ASSOCIATION_RETAIN);
    }
    return result;
}
NSDictionary *timantirecall_legacyRowIdentity(id model,NSString *owner) {
    Class cls=objc_getClass("QQAIOMsgModel");
    if(!cls || ![model isKindOfClass:cls] || !owner.length)return nil;
    id message=timantirecall_legacyObject(model,@"msgModel");
    NSDictionary *snapshot=objc_getAssociatedObject(message,&timantirecall_legacyIdentityKey);
    NSDictionary *identity=snapshot[@"identity"];
    if(![identity[@"owner"] isEqual:owner] ||
       ![snapshot[@"fingerprint"] isEqual:timantirecall_legacyFingerprint(message)])return nil;
    return identity;
}
BOOL timantirecall_installLegacyBridge(void) {
    @synchronized(NSObject.class) {
        if(timantirecall_converterInstalled)return YES;
        Class cls=objc_getClass("NTRecordConverter");
        SEL selector=sel_registerName("recordConvertMessageModel:");
        unsigned count=0;Method own=NULL;
        Method *methods=class_copyMethodList(object_getClass(cls),&count);
        for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==selector){own=methods[i];break;}
        free(methods);
        const char *args[]={"@",":","@"};
        if(!timantirecall_methodTypes(own,"@",3,args))return NO;
        IMP original=method_getImplementation(own);
        if(!original)return NO;
        atomic_store_explicit(&timantirecall_convertOriginal,original,memory_order_release);
        method_setImplementation(own,(IMP)timantirecall_convertMessage);
        timantirecall_converterInstalled=YES;
        return YES;
    }
}
