#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallWire.h"
static unsigned timantirecall_markChecks=0;
#define CHECK(c) do{timantirecall_markChecks++;if(!(c)){NSLog(@"FAIL marks line%d %s",__LINE__,#c);exit(1);}}while(0)
@interface OCMsgRecord : NSObject
@property(nonatomic) int64_t msgId,msgSeq,msgRandom,msgTime,peerUin;
@property(nonatomic) int chatType;
@property(nonatomic,copy) NSString *senderUid,*peerUid;
@end
@implementation OCMsgRecord @end
@interface OCInitSessionConfig : NSObject
@property(nonatomic,copy) NSString *selfUid;
@end
@implementation OCInitSessionConfig @end
@interface QQAccountsManager : NSObject
@property(nonatomic,copy) NSString *currentUid;
+ (instancetype)GetInstance;
@end
@implementation QQAccountsManager
+ (instancetype)GetInstance {static QQAccountsManager *manager;static dispatch_once_t once;dispatch_once(&once,^{manager=[self new];});return manager;}
@end
static unsigned timantirecall_initCalls=0,timantirecall_closeCalls=0;
static NSArray *timantirecall_arguments;
static void timantirecall_fixtureInit(id self,SEL cmd,id config,id depends,id dispatcher,id listener) {
    (void)self;(void)cmd;timantirecall_initCalls++;
    timantirecall_arguments=@[config,depends,dispatcher,listener];
}
static void timantirecall_fixtureClose(id self,SEL cmd,id cb) {
    (void)self;(void)cmd;timantirecall_closeCalls++;timantirecall_arguments=@[cb];
}
static Class timantirecall_sessionFixture(const char *name,const char *encoding) {
    Class cls=objc_allocateClassPair(NSObject.class,name,0);
    class_addMethod(cls,sel_registerName("init:depends:dispatcherDepends:listener:"),(IMP)timantirecall_fixtureInit,encoding);
    class_addMethod(cls,sel_registerName("close:"),(IMP)timantirecall_fixtureClose,"v24@0:8@16");
    objc_registerClassPair(cls);return cls;
}
static void timantirecall_testRowIsolation(void) {
    for(int kind=1;kind<=2;kind++) {
        TIMAntiRecallMarkStore *store=[TIMAntiRecallMarkStore new];
        NSDictionary *last=nil;
        for(int i=0;i<3;i++) {
            NSNumber *seq=@(100+i);
            NSDictionary *event=kind==1?@{@"kind":@1,@"seq":seq,@"from":@"peer",@"to":@"owner"}:
                @{@"kind":@2,@"seq":seq,@"group":@99,@"author":@"peer"};
            NSMutableDictionary *row=[@{@"owner":@"owner",@"kind":@(kind),@"seq":seq,@"id":@(1000+i),
                @"random":@(2000+i),@"time":@1700000000,@"author":@"peer"} mutableCopy];
            if(kind==1)row[@"peer"]=@"peer";else row[@"group"]=@99;
            [store timantirecall_addEvents:@[event] owner:@"owner"];
            CHECK([store timantirecall_containsIdentity:row]);last=row.copy;
        }
        NSMutableDictionary *fourth=last.mutableCopy;fourth[@"id"]=@1003;
        CHECK(![store timantirecall_containsIdentity:fourth]);
        fourth[@"seq"]=@103;CHECK(![store timantirecall_containsIdentity:fourth]);
        CHECK([store timantirecall_containsIdentity:last]);
    }
    TIMAntiRecallMarkStore *collisionStore=[TIMAntiRecallMarkStore new];
    NSDictionary *shared=@{@"kind":@1,@"seq":@501,@"from":@"peer",@"to":@"owner"};
    NSDictionary *same=@{@"owner":@"owner",@"kind":@1,@"seq":@501,@"author":@"peer",@"peer":@"peer",@"id":@501,@"random":@7,@"time":@1700000000};
    [collisionStore timantirecall_addEvents:@[shared] owner:@"owner"];
    CHECK([collisionStore timantirecall_eventForIdentity:same]!=nil);
    CHECK([collisionStore timantirecall_displayCandidateForIdentity:same]!=nil);
    NSMutableDictionary *other=same.mutableCopy;other[@"id"]=@502;
    CHECK([collisionStore timantirecall_displayCandidateForIdentity:other]!=nil);
    [collisionStore timantirecall_suppressDisplayForEvent:[collisionStore timantirecall_eventForIdentity:same]];
    CHECK([collisionStore timantirecall_displayCandidateForIdentity:same]==nil);
    [collisionStore timantirecall_addEvents:@[@{@"kind":@1,@"seq":@501,@"from":@"owner",@"to":@"peer"}] owner:@"owner"];
    CHECK([collisionStore timantirecall_eventForIdentity:same]!=nil);
    CHECK([collisionStore timantirecall_displayCandidateForIdentity:same]==nil);
}
int main(void) {
    @autoreleasepool {timantirecall_testRowIsolation();}
 @autoreleasepool {
    NSString *owner=@"self_uid";
    QQAccountsManager.GetInstance.currentUid=owner;
    CHECK([timantirecall_currentAccount() isEqual:owner]);
    TIMAntiRecallMarkStore *store=[TIMAntiRecallMarkStore new];
    OCMsgRecord *record=[OCMsgRecord new];record.chatType=1;record.msgId=9001;record.msgSeq=42;
    record.peerUid=@"peer_uid";record.senderUid=@"peer_uid";record.msgTime=1700000000;record.msgRandom=123;
    NSDictionary *identity=timantirecall_recordIdentity(record,owner);
    CHECK(identity!=nil);CHECK([identity[@"seq"] longLongValue]==42);CHECK([identity[@"id"] longLongValue]==9001);
    CHECK(![store timantirecall_containsIdentity:identity]);
    NSDictionary *event=@{@"kind":@1,@"seq":@42,@"from":@"peer_uid",@"to":owner};
    [store timantirecall_addEvents:@[event] owner:owner];
    CHECK([store timantirecall_containsIdentity:identity]);
    for(NSString *key in @[@"owner",@"kind",@"seq",@"author",@"peer",@"id",@"random",@"time"]) {
        NSMutableDictionary *wrong=identity.mutableCopy;
        wrong[key]=([key isEqual:@"kind"]||[key isEqual:@"seq"])?@999:@"different_uid";
        CHECK(![store timantirecall_containsIdentity:wrong]);
    }
    record.msgSeq=9001;CHECK(![store timantirecall_containsIdentity:timantirecall_recordIdentity(record,owner)]);
    record.msgSeq=42;
    for(unsigned i=0;i<500;i++)[store timantirecall_addEvents:@[event] owner:owner];
    CHECK([store timantirecall_containsIdentity:identity]);
    [store timantirecall_clear];CHECK(![store timantirecall_containsIdentity:identity]);
    [store timantirecall_addEvents:@[event] owner:@"unrelated_owner"];
    CHECK(![store timantirecall_containsIdentity:identity]);
    NSDictionary *outbound=@{@"kind":@1,@"seq":@42,@"from":owner,@"to":@"peer_uid"};
    [store timantirecall_addEvents:@[outbound] owner:owner];
    record.senderUid=owner;
    CHECK([store timantirecall_containsIdentity:timantirecall_recordIdentity(record,owner)]);
    [store timantirecall_clear];
    record.chatType=2;record.peerUin=5566;record.senderUid=@"member_uid";
    identity=timantirecall_recordIdentity(record,owner);
    NSDictionary *group=@{@"kind":@2,@"group":@5566,@"seq":@42,@"author":@"member_uid",@"random":@123,@"time":@1700000000};
    [store timantirecall_addEvents:@[group] owner:owner];CHECK([store timantirecall_containsIdentity:identity]);
    for(NSString *key in @[@"group",@"random",@"time"]){NSMutableDictionary *wrong=identity.mutableCopy;wrong[key]=@999;CHECK(![store timantirecall_containsIdentity:wrong]);}
    CHECK(timantirecall_recordIdentity(NSObject.new,owner)==nil);
    CHECK(timantirecall_recordIdentity(record,nil)==nil);
    record.chatType=6;CHECK(timantirecall_recordIdentity(record,owner)==nil);record.chatType=2;
    record.msgSeq=0;CHECK(timantirecall_recordIdentity(record,owner)==nil);record.msgSeq=42;
    record.msgId=0;CHECK(timantirecall_recordIdentity(record,owner)==nil);record.msgId=9001;
    [store timantirecall_clear];
    for(unsigned i=0;i<4097;i++)[store timantirecall_addEvents:@[@{@"kind":@2,@"seq":@(i+1),@"group":@5566,@"author":@"member_uid"}] owner:owner];
    record.msgSeq=1;CHECK(![store timantirecall_containsIdentity:timantirecall_recordIdentity(record,owner)]);
    record.msgSeq=4097;CHECK([store timantirecall_containsIdentity:timantirecall_recordIdentity(record,owner)]);
    Class wrongClass=timantirecall_sessionFixture("TIMAntiRecallWrongSession","B48@0:8@16@24@32@40");
    timantirecall_installSessionTracking(wrongClass);
    Class cls=timantirecall_sessionFixture("TIMAntiRecallCorrectSession","v48@0:8@16@24@32@40");
    timantirecall_installSessionTracking(cls);timantirecall_installSessionTracking(cls);
    id session=[cls new];OCInitSessionConfig *config=[OCInitSessionConfig new];config.selfUid=owner;
    NSObject *d=[NSObject new],*p=[NSObject new],*listener=[NSObject new];
    ((void(*)(id,SEL,id,id,id,id))objc_msgSend)(session,sel_registerName("init:depends:dispatcherDepends:listener:"),config,d,p,listener);
    CHECK(timantirecall_initCalls==1);CHECK([timantirecall_sessionOwner(session) isEqual:owner]);
    CHECK(timantirecall_arguments[0]==config && timantirecall_arguments[1]==d && timantirecall_arguments[2]==p && timantirecall_arguments[3]==listener);
    ((void(*)(id,SEL,id))objc_msgSend)(session,sel_registerName("close:"),listener);
    CHECK(timantirecall_closeCalls==1 && timantirecall_arguments[0]==listener);CHECK(timantirecall_sessionOwner(session)==nil);
    NSLog(@"PASS %u native message identity/account/session checks; device untested",timantirecall_markChecks);
 }
 return 0;
}
