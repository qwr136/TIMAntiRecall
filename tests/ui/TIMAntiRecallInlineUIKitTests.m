#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "TIMAntiRecallFixture.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallColdSync.h"
#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallWire.h"
#import "TIMAntiRecallIndicatorView.h"
#import "TIMAntiRecallBootstrap.h"
#import "TIMAntiRecall-Swift.h"

// The only production stub: bootstrap logging, never matching/UI/reflection.
bool timantirecall_bootstrapEvent(const char *event) { (void)event; return true; }
void timantirecall_logEvent(NSString *event) { (void)event; }

static NSMutableArray<NSString *> *timantirecall_failures;
static NSMutableSet<NSString *> *timantirecall_coverage;
static NSUInteger timantirecall_checks;
static NSDictionary *timantirecall_build;
static BOOL timantirecall_started, timantirecall_waitingForBackground;
static BOOL timantirecall_backgroundObserved, timantirecall_resumeObserved;
static UIBackgroundTaskIdentifier timantirecall_backgroundTask;
static BOOL timantirecall_previewWritten, timantirecall_finished;
static UIWindow *timantirecall_window;
static NSArray<TIMAntiRecallTestBaseView *> *timantirecall_demoRows;

static NSString *timantirecall_document(NSString *name) {
    NSString *directory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return [directory stringByAppendingPathComponent:name];
}
static void timantirecall_check(BOOL condition, NSString *name) {
    timantirecall_checks++;
    if(!condition) { [timantirecall_failures addObject:name]; NSLog(@"FAIL %@", name); }
}
static void timantirecall_writeJSON(NSDictionary *value, NSString *name) {
    NSError *error=nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
    if(!data || ![data writeToFile:timantirecall_document(name) options:NSDataWritingAtomic error:&error])
        NSLog(@"Cannot write %@: %@", name, error);
}
static void timantirecall_stage(NSString *name) {
    timantirecall_writeJSON(@{@"stage":name, @"runToken":timantirecall_build[@"runToken"]?:@"", @"checks":@(timantirecall_checks),
                             @"failures":timantirecall_failures?:@[], @"applicationState":@(UIApplication.sharedApplication.applicationState),
                             @"pid":@(NSProcessInfo.processInfo.processIdentifier)}, @"tim-inline-stage.json");
}
static OCMsgRecord *timantirecall_record(int type, int64_t sequence, NSString *peer, int64_t group);
static void timantirecall_finish(void) {
    if(timantirecall_finished)return;
    timantirecall_finished=YES;
    NSError *saveError=nil;
    [timantirecall_settings() timantirecall_setChat:@{@"owner":@"self_uid",@"kind":@2,@"group":@9988} enabled:NO error:&saveError];
    timantirecall_check(!saveError && [timantirecall_sharedMarks() timantirecall_flush:&saveError],@"restart archive and chat config committed before termination");
    NSDictionary *expectedIdentity=timantirecall_recordIdentity(timantirecall_record(1,601,@"peer_a",7001),@"self_uid");
    NSDictionary *expected=[timantirecall_sharedMarks() timantirecall_eventForIdentity:expectedIdentity];
    timantirecall_check([expected[@"capturedAt"] doubleValue]>0,@"first process captures the exact message timestamp");
    timantirecall_writeJSON(@{@"runToken":timantirecall_build[@"runToken"]?:@"",@"pid":@(NSProcessInfo.processInfo.processIdentifier),
                             @"capturedAt":expected[@"capturedAt"]?:@0},@"tim-inline-restart-expected.json");
    timantirecall_writeJSON(@{
        @"status":timantirecall_failures.count?@"FAIL":@"PASS", @"mode":@"real-uikit-scene",
        @"checks":@(timantirecall_checks), @"failures":timantirecall_failures,
        @"coverage":[timantirecall_coverage.allObjects sortedArrayUsingSelector:@selector(compare:)],
        @"runToken":timantirecall_build[@"runToken"]?:@"",
        @"sourceDigest":timantirecall_build[@"sourceDigest"]?:@"",
        @"sceneBackgroundObserved":@(timantirecall_backgroundObserved),
        @"sceneResumeObserved":@(timantirecall_resumeObserved),
        @"previewWritten":@(timantirecall_previewWritten),
        @"systemVersion":UIDevice.currentDevice.systemVersion,
        @"limits":@[@"Synthetic TIM classes; no proprietary TIM host or injection", @"UIKit hit-testing; no injected physical touch", @"Simulator runtime recorded separately from 16.5 deployment target"]
    }, @"tim-inline-result.json");
}
static NSMutableArray<dispatch_block_t> *timantirecall_steps;
static NSTimeInterval timantirecall_stepDelay;
static BOOL timantirecall_holdSteps;
static void timantirecall_step(dispatch_block_t block) { [timantirecall_steps addObject:[block copy]]; }
static void timantirecall_nextStep(void) {
    if(timantirecall_finished || !timantirecall_steps.count)return;
    dispatch_block_t block=timantirecall_steps.firstObject;
    [timantirecall_steps removeObjectAtIndex:0];
    @try { block(); }
    @catch(NSException *exception) {
        timantirecall_check(NO,[@"suite exception: " stringByAppendingString:exception.description]);
        timantirecall_finish();return;
    }
    // Production markIntercepted queues its update before this continuation.
    // Never spin a nested run loop inside a main-dispatch callback.
    if(timantirecall_holdSteps)return;
    NSTimeInterval delay=timantirecall_stepDelay;timantirecall_stepDelay=0;
    if(delay>0)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{timantirecall_nextStep();});
    else dispatch_async(dispatch_get_main_queue(),^{timantirecall_nextStep();});
}
static NSArray<TIMAntiRecallIndicatorView *> *timantirecall_indicators(UIView *root) {
    NSMutableArray *found=[NSMutableArray array];
    if([root isKindOfClass:TIMAntiRecallIndicatorView.class])[found addObject:root];
    for(UIView *child in root.subviews)[found addObjectsFromArray:timantirecall_indicators(child)];
    return found;
}
static void timantirecall_count(UIView *root, NSUInteger expected, NSString *name) {
    timantirecall_check(timantirecall_indicators(root).count==expected, name);
}
static void timantirecall_layout(TIMAntiRecallTestBaseView *view) {
    [view setNeedsLayout]; [view layoutIfNeeded];
}

// Fixtures encode wire data; the production Wire parser and Marks consume it.
static void timantirecall_varint(NSMutableData *data, uint64_t number) {
    do { uint8_t byte=(uint8_t)(number&127); number>>=7; if(number)byte|=128;
        [data appendBytes:&byte length:1]; } while(number);
}
static NSData *timantirecall_number(unsigned field, uint64_t number) {
    NSMutableData *data=[NSMutableData data];timantirecall_varint(data,(uint64_t)field<<3);
    timantirecall_varint(data,number);return data;
}
static NSData *timantirecall_blob(unsigned field, NSData *bytes) {
    NSMutableData *data=[NSMutableData data];timantirecall_varint(data,((uint64_t)field<<3)|2);
    timantirecall_varint(data,bytes.length);[data appendData:bytes];return data;
}
static NSData *timantirecall_join(NSArray<NSData *> *pieces) {
    NSMutableData *data=[NSMutableData data];for(NSData *piece in pieces)[data appendData:piece];return data;
}
static NSData *timantirecall_string(unsigned field, NSString *text) {
    return timantirecall_blob(field,[text dataUsingEncoding:NSUTF8StringEncoding]);
}
static NSData *timantirecall_envelope(unsigned kind, unsigned subtype, NSData *content) {
    NSData *head=timantirecall_join(@[timantirecall_number(1,kind),timantirecall_number(2,subtype)]);
    return timantirecall_blob(1,timantirecall_join(@[timantirecall_blob(2,head),timantirecall_blob(3,timantirecall_blob(2,content))]));
}
static NSData *timantirecall_private(NSString *from, NSString *to, uint64_t seq) {
    NSData *info=timantirecall_join(@[timantirecall_string(1,from),timantirecall_string(2,to),timantirecall_number(20,seq)]);
    return timantirecall_envelope(528,138,timantirecall_blob(1,info));
}
static NSData *timantirecall_group(uint64_t group, NSString *author, uint64_t seq, uint64_t random, uint64_t timestamp) {
    NSData *message=timantirecall_join(@[timantirecall_number(1,seq),timantirecall_number(2,timestamp),
        timantirecall_number(3,random),timantirecall_string(6,author)]);
    NSData *notify=timantirecall_join(@[timantirecall_number(1,7),timantirecall_number(4,group),
        timantirecall_blob(11,timantirecall_blob(3,message))]);
    uint8_t prefix[7]={(uint8_t)(group>>24),(uint8_t)(group>>16),(uint8_t)(group>>8),(uint8_t)group,
        0,(uint8_t)(notify.length>>8),(uint8_t)notify.length};
    NSMutableData *content=[NSMutableData dataWithBytes:prefix length:7];[content appendData:notify];
    return timantirecall_envelope(732,17,content);
}
static OCMsgRecord *timantirecall_record(int type, int64_t sequence, NSString *peer, int64_t group) {
    OCMsgRecord *record=[OCMsgRecord new];record.msgSeq=sequence;record.msgId=900000+sequence;
    record.msgRandom=33;record.msgTime=1700000000;record.chatType=type;record.peerUid=peer;
    record.senderUid=peer;record.peerUin=group;return record;
}
static TIMAntiRecallTestBaseView *timantirecall_row(UIView *host, CGRect frame) {
    TIMAntiRecallTestBaseView *row=[TIMAntiRecallSwiftFixture timantirecall_rowWithFrame:frame];
    [host addSubview:row];return row;
}
static void timantirecall_mark(NSData *packet, NSString *owner) {
    timantirecall_markIntercepted(packet,owner);
}

static void timantirecall_testSwiftAndSession(void) {
    OCMsgRecord *record=timantirecall_record(1,101,@"peer_a",0);
    NSObject *model=[TIMAntiRecallSwiftFixture timantirecall_message:record];
    timantirecall_check([TIMAntiRecallRecordBridge timantirecall_recordForViewModel:model]==record,
                       @"ChatMessage inherits real Swift base record");
    timantirecall_check(![model respondsToSelector:NSSelectorFromString(@"record")],
                       @"record is Swift stored property, no Objective-C getter");
    timantirecall_check([TIMAntiRecallRecordBridge timantirecall_recordForViewModel:
        [TIMAntiRecallSwiftFixture timantirecall_ntMessage:record]]==record,@"NTAIOMessage inherited record");
    timantirecall_check([TIMAntiRecallRecordBridge timantirecall_recordForViewModel:
        [TIMAntiRecallSwiftFixture timantirecall_ntChat:record]]==record,@"NTAIOChat inherited record");
    NSArray *rejected=@[[TIMAntiRecallSwiftFixture timantirecall_gray:record],
        [TIMAntiRecallSwiftFixture timantirecall_recallNotice:record],
        [TIMAntiRecallSwiftFixture timantirecall_baseOnly:record],
        [TIMAntiRecallSwiftFixture timantirecall_invalidRecord:nil],
        [TIMAntiRecallSwiftFixture timantirecall_invalidRecord:NSObject.new],NSObject.new,record];
    for(NSObject *invalid in rejected)
        timantirecall_check([TIMAntiRecallRecordBridge timantirecall_recordForViewModel:invalid]==nil,
                           [@"Swift rejects " stringByAppendingString:NSStringFromClass(invalid.class)]);
    [timantirecall_coverage addObject:@"swift-reflection"];

    timantirecall_installSessionTracking(TIMAntiRecallTestSession.class);
    timantirecall_installSessionTracking(TIMAntiRecallTestSession.class);
    TIMAntiRecallTestSession *session=[TIMAntiRecallTestSession new];
    OCInitSessionConfig *config=[OCInitSessionConfig new];config.selfUid=@"self_uid";
    NSObject *depends=[NSObject new], *dispatcher=[NSObject new], *listener=[NSObject new];
    [session init:config depends:depends dispatcherDepends:dispatcher listener:listener];
    timantirecall_check(session.timantirecall_initCalls==1,@"session init original called exactly once");
    timantirecall_check([session.timantirecall_lastArguments isEqual:@[config,depends,dispatcher,listener]],
                       @"session init preserves all four argument identities");
    timantirecall_check([timantirecall_sessionOwner(session) isEqual:@"self_uid"],@"session captures config owner");
    config.selfUid=@"mutated_uid";
    QQAccountsManager.GetInstance.currentUid=@"other_uid";
    timantirecall_check([timantirecall_sessionOwner(session) isEqual:@"self_uid"],@"session owner is stable copy across account switch");
    QQAccountsManager.GetInstance.currentUid=@"self_uid";
    [session close:listener];
    timantirecall_check(session.timantirecall_closeCalls==1 && session.timantirecall_lastArguments.firstObject==listener,
                       @"session close preserves callback and single original invocation");
    timantirecall_check(timantirecall_sessionOwner(session)==nil,@"session close clears owner");
    [session init:NSObject.new depends:nil dispatcherDepends:nil listener:nil];
    timantirecall_check(timantirecall_sessionOwner(session)==nil && session.timantirecall_initCalls==2,
                       @"unsuitable config forwards original without owner");
    [timantirecall_coverage addObject:@"session-owner"];
}

static void timantirecall_testBindAndPrivate(UIView *host) {
    QQAccountsManager.GetInstance.currentUid=@"self_uid";
    OCMsgRecord *record=timantirecall_record(1,201,@"peer_a",0);
    NSObject *model=[TIMAntiRecallSwiftFixture timantirecall_message:record];
    NSData *packet=timantirecall_private(@"peer_a",@"self_uid",201);
    timantirecall_check(timantirecall_classifyPush(packet.bytes,packet.length)==TIMAntiRecallPrivate,
                       @"private packet reaches real Wire classifier");
    NSArray *events=timantirecall_recallEvents(packet);
    timantirecall_check(events.count==1 && [events.firstObject[@"from"] isEqual:@"peer_a"] &&
                       [events.firstObject[@"to"] isEqual:@"self_uid"],@"Wire preserves private UTF8 UID identity");
    TIMAntiRecallTestBaseView *row=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,90));
    timantirecall_step(^{
    BOOL result=[row bindViewModel:model];
    timantirecall_check(result && row.timantirecall_binds==1 && row.timantirecall_lastBindArgument==model &&
                       row.timantirecall_model==model,@"BOOL YES bind preserves exact model and one original call");
    timantirecall_count(row,0,@"unmarked bound message has no frame");
    timantirecall_mark(packet,@"self_uid");
    });
    timantirecall_step(^{
    timantirecall_count(row,1,@"already-bound target updates on interception");
    timantirecall_mark(packet,@"self_uid");
    timantirecall_mark(packet,@"self_uid");
    });
    timantirecall_step(^{
    timantirecall_count(row,1,@"duplicate interception leaves exactly one frame");
    row.timantirecall_bindResult=NO;
    timantirecall_check(![row bindViewModel:model] && row.timantirecall_binds==2 &&
                       row.timantirecall_lastBindArgument==model && !row.timantirecall_model,
                       @"BOOL NO bind preserves original return and exact argument");
    timantirecall_count(row,0,@"failed rebind removes old frame and never marks");
    timantirecall_mark(packet,@"self_uid");
    });
    timantirecall_step(^{
    timantirecall_count(row,0,@"future event does not decorate failed bind");
    row.timantirecall_bindResult=YES;
    [row bindViewModel:model];timantirecall_count(row,1,@"successful rebind restores retained mark");
    [row bindViewModel:nil];timantirecall_count(row,0,@"nil bound model clears frame safely");
    timantirecall_check(row.timantirecall_lastBindArgument==nil,@"nil argument passed unchanged");
    NSArray *invalid=@[[TIMAntiRecallSwiftFixture timantirecall_gray:record],
        [TIMAntiRecallSwiftFixture timantirecall_baseOnly:record],NSObject.new,
        [TIMAntiRecallSwiftFixture timantirecall_invalidRecord:nil]];
    for(id item in invalid) {
        [row bindViewModel:item];timantirecall_count(row,0,@"ineligible Swift model never decorates row");
    }
    [row bindViewModel:model];
    [row unbindViewModel];
    timantirecall_check(row.timantirecall_unbinds==1 && row.timantirecall_model==nil,@"unbind original invoked once");
    timantirecall_count(row,0,@"unbind clears visual");
    [row bindViewModel:model];timantirecall_count(row,1,@"original message rebind after unbind restores mark");
    [row prepareForReuse];
    timantirecall_check(row.timantirecall_reuses==1 && row.timantirecall_model==nil,@"reuse original invoked once");
    timantirecall_count(row,0,@"prepareForReuse clears visual");
    [row bindViewModel:model];timantirecall_count(row,1,@"original message rebind after reuse restores mark");
    NSUInteger moves=row.timantirecall_windowMoves;
    [row removeFromSuperview];timantirecall_count(row,0,@"leaving real UIWindow clears visual");
    [host addSubview:row];timantirecall_count(row,1,@"returning to real UIWindow restores visual");
    timantirecall_check(row.timantirecall_windowMoves==moves+2,@"window original forwarded on detach and reattach");
    [timantirecall_coverage addObjectsFromArray:@[@"bind-abi",@"reuse-lifecycle"]];

    // Equal rendered message text cannot select any of these identities.
    NSArray<OCMsgRecord *> *records=@[timantirecall_record(1,202,@"peer_a",0),
        timantirecall_record(1,201,@"peer_b",0),timantirecall_record(2,201,@"peer_a",55)];
    for(OCMsgRecord *other in records) {
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:other]];
        timantirecall_count(row,0,@"different sequence, private peer or chat kind does not cross-match");
    }
    [row bindViewModel:model];
    QQAccountsManager.GetInstance.currentUid=@"other_uid";timantirecall_layout(row);
    timantirecall_count(row,0,@"account switch hides original owner frame");
    [row bindViewModel:model];timantirecall_count(row,0,@"same row identity under other account not marked");
    timantirecall_mark(packet,@"self_uid");
    });
    timantirecall_step(^{
    timantirecall_count(row,0,@"stale owner event cannot mark current account");
    QQAccountsManager.GetInstance.currentUid=@"self_uid";
    [row bindViewModel:model];timantirecall_count(row,1,@"rebind original account restores own mark");
    NSData *queued=timantirecall_private(@"peer_a",@"self_uid",299);
    timantirecall_markIntercepted(queued,@"self_uid");
    QQAccountsManager.GetInstance.currentUid=@"other_uid";
    });
    timantirecall_step(^{
    [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,299,@"peer_a",0)]];
    timantirecall_count(row,0,@"durably stored recall stays hidden under another account");
    QQAccountsManager.GetInstance.currentUid=@"self_uid";
    [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,299,@"peer_a",0)]];
    timantirecall_count(row,1,@"intercepted mark remains available to its originating account after switch");
    [row removeFromSuperview];
    [timantirecall_coverage addObjectsFromArray:@[@"private-identity",@"account-isolation",@"durable-intercept"]];
    });
}

static void timantirecall_testGroup(UIView *host) {
    TIMAntiRecallTestBaseView *row=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,90));
    OCMsgRecord *record=timantirecall_record(2,301,@"group_author",7001);
    NSObject *model=[TIMAntiRecallSwiftFixture timantirecall_message:record];
    NSData *packet=timantirecall_group(7001,@"group_author",301,33,1700000000);
    timantirecall_step(^{
    timantirecall_check(timantirecall_classifyPush(packet.bytes,packet.length)==TIMAntiRecallGroup,
                       @"group packet reaches real Wire classifier");
    [row bindViewModel:model];timantirecall_mark(packet,@"self_uid");
    });
    timantirecall_step(^{
    timantirecall_count(row,1,@"group owner/group/author/seq/random/time matches");
    NSArray<NSString *> *fields=@[@"peerUin",@"msgSeq",@"msgRandom",@"msgTime"];
    for(NSString *field in fields) {
        NSNumber *saved=[record valueForKey:field];[record setValue:@(saved.longLongValue+1) forKey:field];
        timantirecall_layout(row);timantirecall_count(row,0,[@"group mismatch rejected: " stringByAppendingString:field]);
        [record setValue:saved forKey:field];timantirecall_layout(row);
        timantirecall_count(row,1,[@"group restored: " stringByAppendingString:field]);
    }
    record.senderUid=@"different_author";timantirecall_layout(row);
    timantirecall_count(row,0,@"other group author cannot share frame");
    record.senderUid=@"group_author";record.chatType=1;timantirecall_layout(row);
    timantirecall_count(row,0,@"group event cannot mark private conversation");
    record.chatType=2;timantirecall_layout(row);
    timantirecall_mark(packet,@"self_uid");
    });
    timantirecall_step(^{
    timantirecall_count(row,1,@"duplicate group recall keeps one frame");
    NSMutableData *malformed=[packet mutableCopy];uint8_t bad=0x80;[malformed appendBytes:&bad length:1];
    timantirecall_check(timantirecall_recallEvents(malformed).count==0,@"malformed event rejected by production parser");
    [timantirecall_coverage addObject:@"group-identity"];
    [row removeFromSuperview];
    });
}

static void timantirecall_testCurrentBinding(UIView *root) {
    TIMAntiRecallTestBaseView *row=timantirecall_row(root,CGRectMake(8,80,root.bounds.size.width-16,100));
    NSObject *target=[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,701,@"peer_a",0)];
    NSObject *other=[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,702,@"peer_a",0)];
    timantirecall_step(^{
        [TIMAntiRecallSwiftFixture timantirecall_directBind:row model:target];
        // Deliberately do not invoke layout here. The recall-time bounded walk
        // must discover this row even when neither binding nor layout was seen.
        timantirecall_check(row.timantirecall_binds==0,@"Swift direct storage bypasses Objective-C bind thunk");
        timantirecall_check([TIMAntiRecallRecordBridge timantirecall_currentModelForView:row]==target,
                           @"production reflection reads actual optional Swift viewModel");
        timantirecall_mark(timantirecall_private(@"peer_a",@"self_uid",701),@"self_uid");
    });
    timantirecall_step(^{
        timantirecall_count(row,1,@"direct Swift bind marks on recall without ObjC bind callback");
        [TIMAntiRecallSwiftFixture timantirecall_directBind:row model:other];timantirecall_layout(row);
        timantirecall_count(row,0,@"direct model replacement clears stale mark");
        [TIMAntiRecallSwiftFixture timantirecall_directBind:row model:target];timantirecall_layout(row);
        timantirecall_count(row,1,@"direct rebind to target restores exactly one mark");
        [TIMAntiRecallSwiftFixture timantirecall_directBind:row model:nil];timantirecall_layout(row);
        timantirecall_count(row,0,@"Swift optional nil removes context and mark");
        timantirecall_check([TIMAntiRecallRecordBridge timantirecall_currentModelForView:NSObject.new]==nil,
                           @"unrelated object has no accepted viewModel storage");
        [row removeFromSuperview];[timantirecall_coverage addObject:@"swift-direct-binding"];
    });
}
static void timantirecall_testLegacyRows(UIView *root) {
    for(NSNumber *kind in @[@1,@2]) {
        int type=kind.intValue;int64_t sequence=800+type;
        QQAIOCell *cell=[[QQAIOCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.frame=CGRectMake(8,80,root.bounds.size.width-16,112);
        OCMsgRecord *record=timantirecall_record(type,sequence,@"peer_a",7001);record.clientSeq=9000+sequence;
        __block QQAIOMsgModel *model;
        __block QQAIOMsgModel *other;
        timantirecall_step(^{
            [root addSubview:cell];[cell layoutIfNeeded];
            model=[QQAIOMsgModel new];model.msgModel=[NTRecordConverter recordConvertMessageModel:record];
            OCMsgRecord *otherRecord=timantirecall_record(type,sequence+10,@"peer_a",7001);otherRecord.clientSeq=12345;
            other=[QQAIOMsgModel new];other.msgModel=[NTRecordConverter recordConvertMessageModel:otherRecord];
            timantirecall_check(model.msgModel.msgSeq==(type==1?record.clientSeq:record.msgSeq),
                               @"fixture preserves TIM private clientSeq/group msgSeq conversion");
            NSDictionary *identity=timantirecall_legacyRowIdentity(model,@"self_uid");
            timantirecall_check([identity[@"seq"] longLongValue]==sequence,@"legacy bridge retains original server identity");
            [cell setAioModel:model];
            timantirecall_check(cell.timantirecall_sets==1 && cell.timantirecall_lastModel==model,
                               @"legacy setter forwards exact argument exactly once");
            NSData *packet=type==1?timantirecall_private(@"peer_a",@"self_uid",sequence):
                timantirecall_group(7001,@"peer_a",sequence,33,1700000000);
            timantirecall_mark(packet,@"self_uid");
        });
        timantirecall_step(^{
            timantirecall_count(cell.contentView,1,@"legacy private/group target has one whole-row indicator");
            CGRect saved=cell.frame;[cell updateCellView];[cell layoutIfNeeded];
            timantirecall_check(CGRectEqualToRect(saved,cell.frame) && cell.timantirecall_updates==1,
                               @"legacy update original and frame preserved");
            timantirecall_count(cell.contentView,1,@"legacy updates do not duplicate indicator");
            [cell setAioModel:other];timantirecall_count(cell.contentView,0,@"legacy reuse to other sequence clears indicator");
            [cell setAioModel:model];timantirecall_count(cell.contentView,1,@"legacy target rebind restores indicator");
            model.msgModel.msgSeq++;[cell updateCellView];
            timantirecall_count(cell.contentView,0,@"mutated converted model invalidates saved identity");
            model.msgModel.msgSeq--;[cell updateCellView];
            timantirecall_count(cell.contentView,1,@"unchanged converted model fingerprint matches");
            QQAccountsManager.GetInstance.currentUid=@"other_uid";[cell updateCellView];
            timantirecall_count(cell.contentView,0,@"converted identity cannot cross account boundary");
            QQAccountsManager.GetInstance.currentUid=@"self_uid";[cell updateCellView];
            timantirecall_count(cell.contentView,1,@"original owner can still display its retained mark");
            RecallNotiAIOModel *notice=[RecallNotiAIOModel new];notice.msgModel=model.msgModel;
            [cell setAioModel:notice];timantirecall_count(cell.contentView,0,@"legacy recall notice is excluded even with same record");
            QQAIOMsgModel *unlinked=[QQAIOMsgModel new];unlinked.msgModel=[QQMessageModel new];
            [cell setAioModel:unlinked];timantirecall_count(cell.contentView,0,@"unlinked old model never falls back to text or legacy sequence");
            [cell setAioModel:model];[cell removeFromSuperview];timantirecall_count(cell.contentView,0,@"legacy off-window mark removed");
            [root addSubview:cell];timantirecall_count(cell.contentView,1,@"legacy on-window model revalidated");
            [cell prepareForReuse];timantirecall_count(cell.contentView,0,@"legacy prepare clears indicator");
            timantirecall_check(cell.timantirecall_reuses==1,@"legacy prepare original called once");
            [cell removeFromSuperview];model=nil;other=nil;
        });
    }
    timantirecall_step(^{[timantirecall_coverage addObject:@"legacy-conversion-binding"];});
}

static void timantirecall_testStartupOwner(UIView *root) {
    TIMAntiRecallTestBaseView *row=timantirecall_row(root,CGRectMake(8,80,root.bounds.size.width-16,100));
    timantirecall_step(^{
        QQAccountsManager.GetInstance.currentUid=@"";
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,925,@"peer_a",0)]];
        timantirecall_count(row,0,@"binding before account setup cannot mark a row");
        QQAccountsManager.GetInstance.currentUid=@"self_uid";
        timantirecall_mark(timantirecall_private(@"peer_a",@"self_uid",925),@"self_uid");
    });
    timantirecall_step(^{
        timantirecall_count(row,1,@"initially empty owner resolves after login and matches recall");
        QQAccountsManager.GetInstance.currentUid=@"other_uid";timantirecall_layout(row);
        timantirecall_count(row,0,@"known owner is never replaced during account switch");
        QQAccountsManager.GetInstance.currentUid=@"self_uid";[row prepareForReuse];[row removeFromSuperview];
        [timantirecall_coverage addObject:@"startup-owner"];
    });
}

static void timantirecall_testPushToRow(UIView *root) {
    TIMAntiRecallTestSession *session=[TIMAntiRecallTestSession new];
    OCInitSessionConfig *config=[OCInitSessionConfig new];config.selfUid=@"self_uid";
    TIMAntiRecallTestBaseView *row=timantirecall_row(root,CGRectMake(8,80,root.bounds.size.width-16,100));
    timantirecall_step(^{
        timantirecall_check(timantirecall_installOnClass(TIMAntiRecallTestSession.class),@"production push hook installed in UIKit app");
        [session init:config depends:nil dispatcherDepends:nil listener:nil];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,951,@"peer_a",0)]];
        NSObject *extra=NSObject.new;NSData *ordinary=[NSData data];NSString *command=@"ordinary";
        [session onMsfPush:command msgBuffer:ordinary pushExtraInfo:extra];
        timantirecall_check(session.timantirecall_pushCalls==1 && session.timantirecall_lastPush[0]==command &&
            session.timantirecall_lastPush[1]==ordinary && session.timantirecall_lastPush[2]==extra,
            @"ordinary push preserves original arguments and one invocation");
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush"
                msgBuffer:timantirecall_private(@"peer_a",@"self_uid",951) pushExtraInfo:extra];
        timantirecall_check(session.timantirecall_pushCalls==1,@"recognized recall is intercepted before original consumer");
        NSDictionary *targetIdentity=timantirecall_recordIdentity(timantirecall_record(1,951,@"peer_a",0),@"self_uid");
        TIMAntiRecallMarkStore *diskReload=[[TIMAntiRecallMarkStore alloc]
            initWithURL:timantirecall_stateURL(@"marks.plist") persistent:YES];
        timantirecall_check([diskReload timantirecall_eventForIdentity:targetIdentity]!=nil,
                           @"intercept identity is readable from a fresh store before push hook returns");
    });
    timantirecall_step(^{
        timantirecall_count(row,1,@"actual push hook/session owner/Wire/Swift/current row produce indicator");
        [session close:nil];[row prepareForReuse];[row removeFromSuperview];
        [timantirecall_coverage addObject:@"push-to-row"];
    });
}

#import "TIMAntiRecallPreferencesCases.h"
#import "TIMAntiRecallPacketCases.h"
#import "TIMAntiRecallPacketOpenCases.h"
#import "TIMAntiRecallPacketToastCases.h"
#import "TIMAntiRecallPacketSeriesCases.h"
#import "TIMAntiRecallPacketFastCases.h"
#import "TIMAntiRecallPacketSilentCases.h"
#import "TIMAntiRecallReplayCases.h"

static void timantirecall_testGeometry(UIView *root) {
    CGFloat width=root.bounds.size.width-16;
    timantirecall_step(^{timantirecall_mark(timantirecall_private(@"peer_a",@"self_uid",401),@"self_uid");});
    for(NSNumber *collection in @[@NO,@YES]) {
        timantirecall_step(^{
        UIView *cell=collection.boolValue?[[UICollectionViewCell alloc] initWithFrame:CGRectMake(8,80,width,112)]:
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.frame=CGRectMake(8,80,width,112);[root addSubview:cell];[cell layoutIfNeeded];
        UIView *host=collection.boolValue?((UICollectionViewCell *)cell).contentView:((UITableViewCell *)cell).contentView;
        // Table/collection contentView contains the sibling avatar AND bubble.
        UIButton *avatar=[UIButton buttonWithType:UIButtonTypeSystem];avatar.frame=CGRectMake(10,18,44,44);
        [avatar setTitle:@"A" forState:UIControlStateNormal];[host addSubview:avatar];
        TIMAntiRecallTestBaseView *bubble=timantirecall_row(host,CGRectMake(66,12,width-80,80));
        UIButton *body=[UIButton buttonWithType:UIButtonTypeSystem];body.frame=bubble.bounds;
        [body setTitle:@"相同文本" forState:UIControlStateNormal];[bubble addSubview:body];
        CGPoint avatarPoint=[avatar convertPoint:CGPointMake(22,22) toView:host];
        CGPoint bodyPoint=[body convertPoint:CGPointMake(30,30) toView:host];
        UIView *beforeAvatar=[host hitTest:avatarPoint withEvent:nil];
        UIView *beforeBody=[host hitTest:bodyPoint withEvent:nil];
        CGRect savedCell=cell.frame,savedHost=host.frame,savedBubble=bubble.frame,savedAvatar=avatar.frame,savedBody=body.frame;
        BOOL savedBubbleInteraction=bubble.userInteractionEnabled;
        NSUInteger layoutCalls=bubble.timantirecall_layouts;
        [bubble bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:timantirecall_record(1,401,@"peer_a",0)]];
        timantirecall_layout(bubble);
        timantirecall_count(host,1,@"one indicator on complete table/collection row");
        TIMAntiRecallIndicatorView *indicator=timantirecall_indicators(host).firstObject;
        timantirecall_check(indicator.superview==host && !timantirecall_indicators(bubble).count,
                           @"indicator belongs to cell contentView, not bubble");
        timantirecall_check(CGRectContainsRect(indicator.frame,avatar.frame) &&
                           CGRectContainsRect(indicator.frame,bubble.frame),@"red frame encloses sibling avatar plus bubble");
        timantirecall_check(CGRectEqualToRect(savedCell,cell.frame) && CGRectEqualToRect(savedHost,host.frame) &&
            CGRectEqualToRect(savedBubble,bubble.frame) && CGRectEqualToRect(savedAvatar,avatar.frame) &&
            CGRectEqualToRect(savedBody,body.frame),@"all existing frames remain unchanged");
        timantirecall_check(bubble.timantirecall_layouts>layoutCalls,@"layout still invokes original implementation");
        timantirecall_check(bubble.userInteractionEnabled==savedBubbleInteraction && !indicator.userInteractionEnabled,
                           @"existing interactivity unchanged; decoration noninteractive");
        UILabel *label=[indicator.subviews.firstObject isKindOfClass:UILabel.class]?(UILabel *)indicator.subviews.firstObject:nil;
        timantirecall_check([label.text isEqualToString:@"已撤回"] && indicator.subviews.count==1,@"single permanent exact 已撤回 label");
        timantirecall_check(CGRectContainsRect(indicator.bounds,label.frame) &&
            CGRectGetMaxX(label.frame)>CGRectGetMidX(indicator.bounds) &&
            CGRectGetMinY(label.frame)>CGRectGetMidY(indicator.bounds),@"label stays inside lower-right corner");
        CGFloat red=0,green=0,blue=0,alpha=0;
        UIColor *stroke=indicator.layer.borderColor?[UIColor colorWithCGColor:indicator.layer.borderColor]:UIColor.clearColor;
        [stroke getRed:&red green:&green blue:&blue alpha:&alpha];
        timantirecall_check(red>green && red>blue && alpha>0 && indicator.layer.borderWidth>0 &&
            indicator.layer.borderWidth<=1.5 && indicator.layer.cornerRadius>0,@"visible thin red rounded stroke");
        timantirecall_check([indicator hitTest:CGPointMake(10,10) withEvent:nil]==nil,@"indicator itself rejects hit testing");
        timantirecall_check(beforeAvatar==avatar && [host hitTest:avatarPoint withEvent:nil]==beforeAvatar,
                           @"avatar touch target passes through unchanged");
        timantirecall_check(beforeBody==body && [host hitTest:bodyPoint withEvent:nil]==beforeBody,
                           @"bubble touch target passes through unchanged");
        [bubble unbindViewModel];timantirecall_count(host,0,@"unbind removes sibling-hosted decoration too");
        [cell removeFromSuperview];
        });
    }
    timantirecall_step(^{[timantirecall_coverage addObjectsFromArray:@[@"row-geometry",@"touch-routing"]];});
}

static void timantirecall_testAmbiguousSequence(UIView *host) {
    __block TIMAntiRecallTestBaseView *first,*second;
    timantirecall_step(^{
        first=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,84));
        second=timantirecall_row(host,CGRectMake(8,170,host.bounds.size.width-16,84));
        OCMsgRecord *target=timantirecall_record(1,779,@"peer_a",0);
        OCMsgRecord *collision=timantirecall_record(1,779,@"peer_a",0);collision.msgId++;
        [first bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:target]];
        [second bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:collision]];
        timantirecall_mark(timantirecall_private(@"peer_a",@"self_uid",779),@"self_uid");
    });
    timantirecall_step(^{
        timantirecall_count(first,0,@"same-sequence collision never marks the first row");
        timantirecall_count(second,0,@"same-sequence collision never marks the other row");
        NSDictionary *event=nil;
        for(NSDictionary *stored in [timantirecall_sharedMarks() timantirecall_eventsForOwner:@"self_uid"])
            if([stored[@"seq"] isEqual:@779] && [stored[@"kind"] isEqual:@1]){event=stored;break;}
        timantirecall_check([event[@"displayAmbiguous"] boolValue],@"ambiguous wire identity is persisted fail-closed");
        [first removeFromSuperview];[second removeFromSuperview];
        [timantirecall_coverage addObject:@"same-sequence-ambiguous"];
    });
}
static void timantirecall_testWeakRelease(UIView *host) {
    timantirecall_step(^{timantirecall_mark(timantirecall_private(@"peer_a",@"self_uid",501),@"self_uid");});
    timantirecall_step(^{
        __weak TIMAntiRecallTestBaseView *weakRow;
        __weak NSObject *weakModel;
        __weak OCMsgRecord *weakRecord;
        __weak TIMAntiRecallIndicatorView *weakIndicator;
        @autoreleasepool {
            TIMAntiRecallTestBaseView *row=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,90));
            @autoreleasepool {
                OCMsgRecord *record=timantirecall_record(1,501,@"peer_a",0);
                NSObject *model=[TIMAntiRecallSwiftFixture timantirecall_message:record];
                [row bindViewModel:model];
                weakRow=row;weakModel=model;weakRecord=record;weakIndicator=timantirecall_indicators(row).firstObject;
                timantirecall_check(weakIndicator!=nil,@"release test starts with marked visible row");
                // Host drops its model while the row remains bound/visible.
                row.timantirecall_model=nil;
            }
            timantirecall_check(!weakModel && !weakRecord,@"row context holds Swift model and record weakly");
            [row removeFromSuperview];
        }
        timantirecall_check(!weakRow && !weakModel && !weakRecord && !weakIndicator,
                           @"global row tracking retains neither view, model, record nor indicator");
        [timantirecall_coverage addObject:@"weak-release"];
    });
}

static void timantirecall_makePreview(UIView *root) {
    root.backgroundColor=UIColor.systemBackgroundColor;
    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(18,56,root.bounds.size.width-36,50)];
    title.text=@"TIM · Inline recall integration";title.font=[UIFont boldSystemFontOfSize:18];
    title.numberOfLines=2;[root addSubview:title];
    NSMutableArray *rows=[NSMutableArray array];
    for(NSUInteger index=0;index<3;index++) {
        UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.frame=CGRectMake(8,120+index*112,root.bounds.size.width-16,102);[root addSubview:cell];[cell layoutIfNeeded];
        UIView *host=cell.contentView;
        UILabel *avatar=[[UILabel alloc] initWithFrame:CGRectMake(12,20,42,42)];
        avatar.text=@"TIM";avatar.textAlignment=NSTextAlignmentCenter;avatar.backgroundColor=UIColor.systemBlueColor;
        avatar.textColor=UIColor.whiteColor;avatar.layer.cornerRadius=10;avatar.clipsToBounds=YES;[host addSubview:avatar];
        TIMAntiRecallTestBaseView *row=timantirecall_row(host,CGRectMake(66,14,host.bounds.size.width-80,72));
        row.backgroundColor=UIColor.secondarySystemBackgroundColor;row.layer.cornerRadius=9;
        UILabel *message=[[UILabel alloc] initWithFrame:CGRectMake(12,10,row.bounds.size.width-24,26)];
        message.text=@"相同文本";message.font=[UIFont systemFontOfSize:18];[row addSubview:message];
        UILabel *identity=[[UILabel alloc] initWithFrame:CGRectMake(12,39,row.bounds.size.width-24,22)];
        identity.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
        identity.textColor=UIColor.secondaryLabelColor;
        identity.text=index==0?@"private peer_a · seq 601":index==1?@"private peer_a · seq 602":@"group 7001 · seq 603";
        [row addSubview:identity];
        OCMsgRecord *record=timantirecall_record(index==2?2:1,601+(int64_t)index,@"peer_a",7001);
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:record]];[rows addObject:row];
    }
    timantirecall_demoRows=[rows copy];
    timantirecall_mark(timantirecall_private(@"peer_a",@"self_uid",601),@"self_uid");
    timantirecall_mark(timantirecall_group(7001,@"peer_a",603,33,1700000000),@"self_uid");
    UILabel *note=[[UILabel alloc] initWithFrame:CGRectMake(18,470,root.bounds.size.width-36,100)];
    note.text=@"Real UIKit + production Swift Mirror\nRow 1 + 3: 已撤回; row 2: unchanged\nActual scene background/resume follows.";
    note.numberOfLines=0;note.font=[UIFont systemFontOfSize:13];note.textColor=UIColor.secondaryLabelColor;
    [root addSubview:note];
}

static void timantirecall_capturePreview(void) {
    [timantirecall_window layoutIfNeeded];
    __block BOOL drawn=NO;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithBounds:timantirecall_window.bounds];
    UIImage *image=[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        drawn=[timantirecall_window drawViewHierarchyInRect:timantirecall_window.bounds afterScreenUpdates:YES];
    }];
    NSData *png=UIImagePNGRepresentation(image);
    timantirecall_previewWritten=drawn && png.length>128 &&
        [png writeToFile:timantirecall_document(@"tim-inline-preview.png") atomically:YES];
    timantirecall_check(timantirecall_previewWritten,@"real drawViewHierarchy preview saved successfully");
}

#import "TIMAntiRecallRestartCases.h"
#import "TIMAntiRecallReplayTouchHost.h"

static void timantirecall_start(void) {
    if(timantirecall_started)return;
    if([NSProcessInfo.processInfo.arguments containsObject:@"--timantirecall-replay-touch-only"]) {
        timantirecall_started=YES;timantirecall_startReplayTouchHost();return;
    }
    if([NSProcessInfo.processInfo.arguments containsObject:@"--timantirecall-restore-only"]) {
        timantirecall_started=YES;timantirecall_testRestartStart();return;
    }
    timantirecall_started=YES;
    timantirecall_failures=[NSMutableArray array];timantirecall_coverage=[NSMutableSet set];
    timantirecall_steps=[NSMutableArray array];
    NSData *receipt=[NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"tim-inline-build" ofType:@"json"]];
    timantirecall_build=receipt?[NSJSONSerialization JSONObjectWithData:receipt options:0 error:NULL]:@{};
    timantirecall_stage(@"running");
    @try {
        timantirecall_check(NSThread.isMainThread && timantirecall_window.windowScene.activationState==UISceneActivationStateForegroundActive,
                           @"suite runs in foreground active real UIWindowScene on main thread");
        timantirecall_check(timantirecall_installInlineIndicator(),@"production inline hook installation succeeds");
        timantirecall_check(timantirecall_installInlineIndicator(),@"production inline hook installation idempotent");
        timantirecall_testSwiftAndSession();
        UIView *root=timantirecall_window.rootViewController.view;
        timantirecall_testBindAndPrivate(root);
        timantirecall_testGroup(root);
        timantirecall_testCurrentBinding(root);
        timantirecall_testLegacyRows(root);
        timantirecall_testStartupOwner(root);
        timantirecall_testPushToRow(root);
        timantirecall_testGeometry(root);
        timantirecall_testAmbiguousSequence(root);
        timantirecall_testWeakRelease(root);
        timantirecall_testRecallSettings(root);
        timantirecall_testMessageReplay(root);
        timantirecall_testPreferencesPanel();
        timantirecall_testPacketOpenGuards();
        timantirecall_testProxyRejections();
        timantirecall_testSilentPackets();
        timantirecall_testSilentLateReceipt();
        timantirecall_testSilentManualContention();
        timantirecall_testSilentNativeEnvelope();
        timantirecall_testFastPacketIngress();
        timantirecall_testPacketAmountToast();
        timantirecall_step(^{timantirecall_makePreview(root);});
        timantirecall_step(^{
            timantirecall_count(root,2,@"three equal-text messages: only private and group targets marked");
            timantirecall_count(timantirecall_demoRows[1].superview,0,@"equal text with different seq stays undecorated");
            // Decoration must remain through several real layout/run-loop turns.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.75*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                @try {
                    for(TIMAntiRecallTestBaseView *row in timantirecall_demoRows)timantirecall_layout(row);
                    timantirecall_count(root,2,@"已撤回 remains visible after idle/layout, not a transient toast");
                    timantirecall_capturePreview();
                    timantirecall_prepareSilentBackground();
                    timantirecall_waitingForBackground=YES;
                    timantirecall_stage(@"ready-for-background");
                } @catch(NSException *exception) {
                    timantirecall_check(NO,[@"preview exception: " stringByAppendingString:exception.description]);timantirecall_finish();
                }
            });
        });
        timantirecall_nextStep();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,180*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            if(!timantirecall_finished) {
                timantirecall_check(NO,@"scene lifecycle watchdog expired after 180 seconds");timantirecall_finish();
            }
        });
    } @catch(NSException *exception) {
        timantirecall_check(NO,[@"suite exception: " stringByAppendingString:exception.description]);timantirecall_finish();
    }
}

@interface TIMAntiRecallTestSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation TIMAntiRecallTestSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)session;(void)options;
    self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController=[UIViewController new];
    self.window.rootViewController.view.backgroundColor=UIColor.systemBackgroundColor;
    timantirecall_window=self.window;[self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    if(!timantirecall_started) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{timantirecall_start();});
    } else if(timantirecall_backgroundObserved && !timantirecall_finished) {
        // UIKit posts active notifications after the delegate callback; test after
        // that cycle, with no synthetic notification or forced layout refresh.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            timantirecall_check(scene.activationState==UISceneActivationStateForegroundActive,@"scene truly returned foreground active");
            timantirecall_count(self.window.rootViewController.view,2,@"production observers restore frames on real scene activation");
            timantirecall_count(timantirecall_demoRows[1].superview,0,@"unmarked row stays clean across scene lifecycle");
            timantirecall_resumeObserved=YES;[timantirecall_coverage addObject:@"real-scene-resume"];
            if(timantirecall_backgroundTask!=UIBackgroundTaskInvalid) {
                [UIApplication.sharedApplication endBackgroundTask:timantirecall_backgroundTask];timantirecall_backgroundTask=UIBackgroundTaskInvalid;
            }
            timantirecall_finish();
        });
    }
}
- (void)sceneWillResignActive:(UIScene *)scene {
    (void)scene;
    if(timantirecall_waitingForBackground)timantirecall_stage(@"scene-will-deactivate");
}
- (void)sceneDidEnterBackground:(UIScene *)scene {
    if(!timantirecall_waitingForBackground || timantirecall_finished)return;
    timantirecall_stage(@"scene-entered-background");
    dispatch_async(dispatch_get_main_queue(),^{
        timantirecall_check(scene.activationState==UISceneActivationStateBackground,@"scene truly entered system background");
        timantirecall_count(self.window.rootViewController.view,2,@"verified recall frames remain visible in app-switcher background snapshot");
        timantirecall_count(timantirecall_demoRows[1].superview,0,@"unmarked row stays clean in background snapshot");
        timantirecall_backgroundObserved=YES;[timantirecall_coverage addObject:@"real-scene-background"];
        timantirecall_beginSilentBackground(scene,^{
            // Keep the TEST-only lease until the same scene actually resumes;
            // simctl launch is asynchronous and must not silently create a new PID.
            timantirecall_stage(@"background-observed");
        });
    });
}
@end

@interface TIMAntiRecallTestAppDelegate : UIResponder <UIApplicationDelegate> @end
@implementation TIMAntiRecallTestAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application;(void)options;return YES;
}
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)application;(void)options;
    UISceneConfiguration *configuration=[[UISceneConfiguration alloc] initWithName:@"Inline tests" sessionRole:session.role];
    configuration.delegateClass=TIMAntiRecallTestSceneDelegate.class;return configuration;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(TIMAntiRecallTestAppDelegate.class)); }
}
