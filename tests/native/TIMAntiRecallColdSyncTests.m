#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "TIMAntiRecallColdSync.h"
#import "TIMAntiRecallMarks.h"
#include <stdlib.h>
static unsigned checks;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){NSLog(@"FAIL cold line%d %s",__LINE__,#__VA_ARGS__);exit(1);}}while(0)
@interface OCMsgRecord:NSObject
@property(nonatomic) int64_t msgId,msgSeq,msgRandom,msgTime,peerUin,recallTime;
@property(nonatomic) int chatType;
@property(nonatomic,copy) NSString *senderUid,*peerUid;
@property(nonatomic) NSUInteger setterCalls;
@end
@implementation OCMsgRecord
- (void)setRecallTime:(int64_t)value {_recallTime=value;_setterCalls++;}
@end
@interface QQAccountsManager:NSObject
@property(nonatomic,copy) NSString *currentUid;+(instancetype)GetInstance;
@end
@implementation QQAccountsManager
+(instancetype)GetInstance {static QQAccountsManager *m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
@end
int main(void){@autoreleasepool {
    NSString *owner=@"self_uid";QQAccountsManager.GetInstance.currentUid=owner;
    timantirecall_prepareState();TIMAntiRecallMarkStore *store=timantirecall_sharedMarks();
    NSDictionary *event=@{@"kind":@1,@"seq":@42,@"from":@"peer_uid",@"to":owner};
    [store timantirecall_addEvents:@[event] owner:owner capturedAt:1700000000];
    NSError *flushError=nil;CHECK([store timantirecall_flush:&flushError]&&!flushError);
    CHECK(timantirecall_installColdRecallProtection());
    CHECK(timantirecall_installColdRecallProtection());
    OCMsgRecord *marked=[OCMsgRecord new];marked.chatType=1;marked.msgId=9001;marked.msgSeq=42;marked.msgRandom=123;marked.msgTime=1700000000;marked.peerUid=@"peer_uid";marked.senderUid=@"peer_uid";
    [marked setRecallTime:1700000000];
    CHECK(marked.recallTime==0 && marked.setterCalls==0);
    NSDictionary *groupEvent=@{@"kind":@2,@"group":@5566,@"seq":@77,@"author":@"member_uid"};
    [store timantirecall_addEvents:@[groupEvent] owner:owner capturedAt:1700000000];
    OCMsgRecord *markedGroup=[OCMsgRecord new];markedGroup.chatType=2;markedGroup.msgId=9077;markedGroup.msgSeq=77;markedGroup.msgRandom=123;markedGroup.msgTime=1700000000;markedGroup.peerUin=5566;markedGroup.peerUid=@"group_uid";markedGroup.senderUid=@"member_uid";
    [markedGroup setRecallTime:1700000002];CHECK(markedGroup.recallTime==0 && markedGroup.setterCalls==0);
    OCMsgRecord *wrongGroup=[OCMsgRecord new];wrongGroup.chatType=2;wrongGroup.msgId=9078;wrongGroup.msgSeq=77;wrongGroup.msgRandom=123;wrongGroup.msgTime=1700000000;wrongGroup.peerUin=5567;wrongGroup.peerUid=@"group_uid";wrongGroup.senderUid=@"member_uid";
    [wrongGroup setRecallTime:1700000003];CHECK(wrongGroup.recallTime==1700000003 && wrongGroup.setterCalls==1);
    OCMsgRecord *other=[OCMsgRecord new];other.chatType=1;other.msgId=9002;other.msgSeq=43;other.msgRandom=124;other.msgTime=1700000000;other.peerUid=@"peer_uid";other.senderUid=@"peer_uid";
    [other setRecallTime:1700000001];CHECK(other.recallTime==1700000001 && other.setterCalls==1);
    [marked setRecallTime:0];CHECK(marked.recallTime==0 && marked.setterCalls==1);
    QQAccountsManager.GetInstance.currentUid=@"other_uid";OCMsgRecord *cross=[OCMsgRecord new];cross.chatType=1;cross.msgId=9001;cross.msgSeq=42;cross.msgRandom=123;cross.msgTime=1700000000;cross.peerUid=@"peer_uid";cross.senderUid=@"peer_uid";
    [cross setRecallTime:1700000001];CHECK(cross.recallTime==1700000001 && cross.setterCalls==1);
    NSLog(@"PASS %u cold recall setter protection checks; device untested",checks);return 0;
}}
