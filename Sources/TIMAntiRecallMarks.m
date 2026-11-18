#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallWire.h"
#include <string.h>

BOOL timantirecall_methodTypes(Method method,const char *result,unsigned argumentCount,const char * const *arguments) {
    if (!method || method_getNumberOfArguments(method)!=argumentCount) return NO;
    char buffer[128]={0};method_getReturnType(method,buffer,sizeof(buffer));
    if(strcmp(buffer,result)!=0) return NO;
    for(unsigned i=0;i<argumentCount;i++) {
        memset(buffer,0,sizeof(buffer));method_getArgumentType(method,i,buffer,sizeof(buffer));
        if(strcmp(buffer,arguments[i])!=0) return NO;
    }
    return YES;
}
static BOOL timantirecall_getter(id object,NSString *name,const char *result) {
    const char *args[]={"@",":"};
    return object && timantirecall_methodTypes(class_getInstanceMethod(object_getClass(object),NSSelectorFromString(name)),result,2,args);
}
static id timantirecall_object(id object,NSString *name) {
    if(!timantirecall_getter(object,name,"@")) return nil;
    SEL selector=NSSelectorFromString(name);
    return ((id(*)(id,SEL))[object methodForSelector:selector])(object,selector);
}
static int64_t timantirecall_integer(id object,NSString *name) {
    SEL selector=NSSelectorFromString(name);
    return ((int64_t(*)(id,SEL))[object methodForSelector:selector])(object,selector);
}
static BOOL timantirecall_uid(id value) {
    if(![value isKindOfClass:NSString.class] || [value length]==0 || [value length]>128) return NO;
    static NSCharacterSet *bad;static dispatch_once_t once;
    dispatch_once(&once,^{bad=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet];});
    return [value rangeOfCharacterFromSet:bad].location==NSNotFound;
}
NSString *timantirecall_currentAccount(void) {
    Class cls=objc_getClass("QQAccountsManager");
    const char *args[]={"@",":"};SEL shared=sel_registerName("GetInstance");
    if(!cls || !timantirecall_methodTypes(class_getClassMethod(cls,shared),"@",2,args)) return nil;
    id manager=((id(*)(id,SEL))method_getImplementation(class_getClassMethod(cls,shared)))(cls,shared);
    id uid=timantirecall_object(manager,@"currentUid");
    return timantirecall_uid(uid)?[uid copy]:nil;
}
NSArray<NSDictionary *> *timantirecall_recallEvents(NSData *data) {
    if(![data isKindOfClass:NSData.class])return @[];
    TIMAntiRecallWireEvent events[64];
    size_t count=timantirecall_extractRecallEvents(data.bytes,data.length,events,64);
    NSMutableArray *result=[NSMutableArray arrayWithCapacity:count];
    for(size_t i=0;i<count;i++) {
        TIMAntiRecallWireEvent e=events[i];
        NSMutableDictionary *event=[@{@"kind":@(e.kind),@"seq":@(e.sequence)} mutableCopy];
        if(e.kind==1) {event[@"from"]=@(e.from);event[@"to"]=@(e.to);}
        else {event[@"group"]=@(e.group);event[@"author"]=@(e.author);
            if(e.hasRandom)event[@"random"]=@(e.random);
            if(e.hasTime)event[@"time"]=@(e.time);}
        [result addObject:event];
    }
    return result;
}
NSDictionary *timantirecall_recordIdentity(id record,NSString *owner) {
    Class cls=objc_getClass("OCMsgRecord");
    if(!timantirecall_uid(owner)||!cls||![record isKindOfClass:cls])return nil;
    for(NSString *name in @[@"msgSeq",@"msgId",@"msgRandom",@"msgTime",@"peerUin"])
        if(!timantirecall_getter(record,name,"q"))return nil;
    if(!timantirecall_getter(record,@"chatType","i"))return nil;
    SEL type=sel_registerName("chatType");
    int kind=((int(*)(id,SEL))[record methodForSelector:type])(record,type);
    int64_t seq=timantirecall_integer(record,@"msgSeq");
    int64_t messageID=timantirecall_integer(record,@"msgId");
    id author=timantirecall_object(record,@"senderUid");
    id peer=timantirecall_object(record,@"peerUid");
    if(seq<=0 || !messageID || !timantirecall_uid(author) || (kind!=1 && kind!=2))return nil;
    NSMutableDictionary *identity=[@{@"owner":owner,@"kind":@(kind),@"seq":@(seq),@"id":@(messageID),
        @"author":author,@"random":@(timantirecall_integer(record,@"msgRandom")),
        @"time":@(timantirecall_integer(record,@"msgTime"))} mutableCopy];
    if(kind==1) {
        if(!timantirecall_uid(peer) || (![author isEqualToString:owner]&&![author isEqualToString:peer]))return nil;
        identity[@"peer"]=peer;
    } else {
        int64_t group=timantirecall_integer(record,@"peerUin");
        if(group<=0)return nil;
        identity[@"group"]=@(group);
    }
    return identity;
}

@interface TIMAntiRecallMarkStore ()
@property(nonatomic,strong) NSMutableArray<NSDictionary *> *timantirecall_events;
@end
@implementation TIMAntiRecallMarkStore
- (instancetype)init {self=[super init];if(self)_timantirecall_events=[NSMutableArray array];return self;}
- (void)timantirecall_addEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner {
    if(!timantirecall_uid(owner))return;
    @synchronized(self) {
        for(NSDictionary *event in events) {
            if(![event isKindOfClass:NSDictionary.class] || [event[@"seq"] unsignedLongLongValue]==0)continue;
            NSMutableDictionary *e=[event mutableCopy];e[@"owner"]=owner;
            unsigned kind=[e[@"kind"] unsignedIntValue];
            if(kind==1) {
                if(!timantirecall_uid(e[@"from"])||!timantirecall_uid(e[@"to"]))continue;
                if([e[@"from"] isEqual:owner])e[@"peer"]=e[@"to"];
                else if([e[@"to"] isEqual:owner])e[@"peer"]=e[@"from"];
                else continue;
                e[@"author"]=e[@"from"];
            }else if(kind!=2 || [e[@"group"] unsignedLongLongValue]==0 || !timantirecall_uid(e[@"author"]))continue;
            if([self.timantirecall_events containsObject:e])continue;
            [self.timantirecall_events addObject:[e copy]];
            if(self.timantirecall_events.count>4096)[self.timantirecall_events removeObjectAtIndex:0];
        }
    }
}
- (BOOL)timantirecall_containsIdentity:(NSDictionary *)identity {
    if(!identity)return NO;
    @synchronized(self) {
        for(NSDictionary *event in self.timantirecall_events.reverseObjectEnumerator) {
            if(![event[@"owner"] isEqual:identity[@"owner"]]||![event[@"kind"] isEqual:identity[@"kind"]]||
               ![event[@"seq"] isEqual:identity[@"seq"]]||![event[@"author"] isEqual:identity[@"author"]])continue;
            NSString *key=[event[@"kind"] intValue]==1?@"peer":@"group";
            if(![event[key] isEqual:identity[key]])continue;
            if(event[@"random"] && ![event[@"random"] isEqual:identity[@"random"]])continue;
            if(event[@"time"] && ![event[@"time"] isEqual:identity[@"time"]])continue;
            return YES;
        }
    }
    return NO;
}
- (void)timantirecall_clear {@synchronized(self){[self.timantirecall_events removeAllObjects];}}
@end
