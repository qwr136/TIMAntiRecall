#pragma once
// Included after the suite's fixture builders. These tests enter the production
// runtime/session hooks; no direct markIntercepted shortcut for own callbacks.
static NSData *timantirecall_ownCasePacket(BOOL group, unsigned subtype, NSString *actor,
                                         NSString *author, uint64_t sequence) {
    if(!group) {
        NSMutableArray *parts=[NSMutableArray arrayWithObjects:timantirecall_string(2,@"peer_a"),
                               timantirecall_number(20,sequence),nil];
        if(actor)[parts addObject:timantirecall_string(1,actor)];
        return timantirecall_envelope(528,subtype,timantirecall_blob(1,timantirecall_join(parts)));
    }
    NSMutableArray *parts=[NSMutableArray arrayWithObjects:timantirecall_number(1,sequence),
        timantirecall_number(2,1700000000),timantirecall_number(3,33),nil];
    if(author)[parts addObject:timantirecall_string(6,author)];
    NSData *recall=timantirecall_blob(3,timantirecall_join(parts));
    if(actor)recall=timantirecall_join(@[timantirecall_string(1,actor),recall]);
    NSData *notify=timantirecall_join(@[timantirecall_number(1,7),timantirecall_number(4,7001),
                                      timantirecall_blob(11,recall)]);
    uint8_t prefix[]={0,0,27,89,0,(uint8_t)(notify.length>>8),(uint8_t)notify.length};
    return timantirecall_envelope(732,subtype,timantirecall_join(@[[NSData dataWithBytes:prefix length:7],notify]));
}
static void timantirecall_ownCaseForward(TIMAntiRecallTestSession *session, NSData *packet, NSString *name) {
    NSString *command=@"trpc.msg.olpush.OlPushService.MsgPush";NSObject *extra=NSObject.new;
    NSUInteger before=session.timantirecall_pushCalls;
    [session onMsfPush:command msgBuffer:packet pushExtraInfo:extra];
    timantirecall_check(session.timantirecall_pushCalls==before+1,[name stringByAppendingString:@": original once"]);
    timantirecall_check(session.timantirecall_lastPush.count==3 && session.timantirecall_lastPush[0]==command &&
        session.timantirecall_lastPush[1]==packet && session.timantirecall_lastPush[2]==extra,
        [name stringByAppendingString:@": exact argument identities"]);
}
static void timantirecall_testOwnRecall(UIView *host) {
    TIMAntiRecallTestSession *session=[TIMAntiRecallTestSession new];
    timantirecall_step(^{
        QQAccountsManager.GetInstance.currentUid=@"self_uid";
        timantirecall_check(timantirecall_installOnClass(TIMAntiRecallTestSession.class),@"own case uses production push hook");
        timantirecall_installSessionTracking(TIMAntiRecallTestSession.class);
        OCInitSessionConfig *config=[OCInitSessionConfig new];config.selfUid=@"self_uid";
        [session init:config depends:nil dispatcherDepends:nil listener:nil];
        timantirecall_check(session.timantirecall_initCalls==1 && [timantirecall_sessionOwner(session) isEqual:@"self_uid"],
                           @"own case obtains owner from actual session init hook");
    });
    for(NSNumber *subtype in @[@138,@139,@16,@17]) {
        BOOL group=subtype.unsignedIntValue<100;int64_t sequence=18000+subtype.longLongValue;
        OCMsgRecord *record=timantirecall_record(group?2:1,sequence,@"peer_a",group?7001:0);
        record.senderUid=group?@"other_author":@"self_uid";
        OCMsgRecord *next=timantirecall_record(group?2:1,sequence+1000,@"peer_a",group?7001:0);
        next.senderUid=record.senderUid;
        NSObject *model=[TIMAntiRecallSwiftFixture timantirecall_message:record];
        NSObject *nextModel=[TIMAntiRecallSwiftFixture timantirecall_message:next];
        __block TIMAntiRecallTestBaseView *row,*neighbor;
        timantirecall_step(^{
            row=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,84));
            neighbor=timantirecall_row(host,CGRectMake(8,170,host.bounds.size.width-16,84));
            [row bindViewModel:model];[neighbor bindViewModel:nextModel];
            NSData *packet=timantirecall_ownCasePacket(group,subtype.unsignedIntValue,@"self_uid",record.senderUid,sequence);
            timantirecall_check(timantirecall_classifyPush(packet.bytes,packet.length)==(group?TIMAntiRecallGroup:TIMAntiRecallPrivate),
                               @"own packet remains a recognized recall at the unchanged classifier");
            NSUInteger before=[timantirecall_sharedMarks() timantirecall_eventsForOwner:@"self_uid"].count;
            timantirecall_ownCaseForward(session,packet,[NSString stringWithFormat:@"own subtype %@",subtype]);
            timantirecall_check([timantirecall_sharedMarks() timantirecall_eventsForOwner:@"self_uid"].count==before,
                               @"own runtime callback creates no mark");
        });
        timantirecall_step(^{
            timantirecall_count(row,0,@"own recalled row has no indicator after queued UI work");
            timantirecall_count(neighbor,0,@"adjacent unrecalled row has no indicator");
            timantirecall_check(![timantirecall_sharedMarks() timantirecall_containsRecallEventForIdentity:
                timantirecall_recordIdentity(record,@"self_uid")],@"own callback never creates cold-sync protection");
            [row bindViewModel:model];timantirecall_layout(row);
            timantirecall_count(row,0,@"rebind cannot resurrect own recall indicator");
            [row removeFromSuperview];[neighbor removeFromSuperview];
        });
    }
    // A legacy group mark without operator is retained until an exact own
    // callback clears it. Keep a neighboring mark to detect overbroad deletion.
    OCMsgRecord *oldRecord=timantirecall_record(2,18200,@"old_author",7001);
    OCMsgRecord *keptRecord=timantirecall_record(2,18201,@"old_author",7001);
    __block TIMAntiRecallTestBaseView *oldRow,*keptRow;
    timantirecall_step(^{
        oldRow=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,84));
        keptRow=timantirecall_row(host,CGRectMake(8,170,host.bounds.size.width-16,84));
        for(OCMsgRecord *record in @[oldRecord,keptRecord])
            [timantirecall_sharedMarks() timantirecall_addEvents:@[@{@"kind":@2,@"group":@7001,@"seq":@(record.msgSeq),
                @"author":@"old_author",@"random":@33,@"time":@1700000000}] owner:@"self_uid"];
        [oldRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:oldRecord]];
        [keptRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:keptRecord]];
        timantirecall_count(oldRow,1,@"legacy target has its old indicator before own recall");
        timantirecall_count(keptRow,1,@"neighbor has an independent old mark");
        timantirecall_ownCaseForward(session,timantirecall_ownCasePacket(YES,17,@"self_uid",nil,18200),@"own without author clears old target");
    });
    timantirecall_step(^{
        timantirecall_count(oldRow,0,@"own callback removes already-visible old indicator");
        timantirecall_count(keptRow,1,@"own callback preserves another message's old indicator");
        timantirecall_check(![timantirecall_sharedMarks() timantirecall_containsRecallEventForIdentity:
            timantirecall_recordIdentity(oldRecord,@"self_uid")],@"own old target no longer blocks cold sync");
        timantirecall_check([timantirecall_sharedMarks() timantirecall_containsRecallEventForIdentity:
            timantirecall_recordIdentity(keptRecord,@"self_uid")],@"neighbor retains cold-sync protection");
        // Display-ineligible marks must still be removed: this catches an
        // implementation that only consults displayCandidateForIdentity.
        NSDictionary *hidden=@{@"kind":@2,@"group":@7001,@"seq":@18202,@"author":@"old_author",@"displayAmbiguous":@YES};
        [timantirecall_sharedMarks() timantirecall_addEvents:@[hidden] owner:@"self_uid"];
        NSDictionary *identity=timantirecall_recordIdentity(timantirecall_record(2,18202,@"old_author",7001),@"self_uid");
        timantirecall_check([timantirecall_sharedMarks() timantirecall_containsRecallEventForIdentity:identity] &&
            ![timantirecall_sharedMarks() timantirecall_displayCandidateForIdentity:identity],@"hidden old mark exists without display candidate");
        timantirecall_ownCaseForward(session,timantirecall_ownCasePacket(YES,16,@"self_uid",@"old_author",18202),@"own clears hidden old target");
        timantirecall_check(![timantirecall_sharedMarks() timantirecall_containsRecallEventForIdentity:identity],@"hidden own target cleared by wire identity");
        [oldRow removeFromSuperview];[keptRow removeFromSuperview];
    });
    // Operator, not message author, decides whether a recall is ours.
    OCMsgRecord *selfAuthored=timantirecall_record(2,18210,@"self_uid",7001);
    __block TIMAntiRecallTestBaseView *thirdRow;
    timantirecall_step(^{
        thirdRow=timantirecall_row(host,CGRectMake(8,80,host.bounds.size.width-16,84));
        [thirdRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:selfAuthored]];
        NSUInteger before=session.timantirecall_pushCalls;
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush"
            msgBuffer:timantirecall_ownCasePacket(YES,17,@"third_actor",@"self_uid",18210) pushExtraInfo:NSObject.new];
        timantirecall_check(session.timantirecall_pushCalls==before,@"third operator recalling self author remains blocked");
        NSData *noAuthor=timantirecall_ownCasePacket(YES,16,@"third_actor",nil,18211);
        timantirecall_check(timantirecall_classifyPush(noAuthor.bytes,noAuthor.length)==TIMAntiRecallGroup,
                           @"no-author fixture is still a recognized group recall");
        [session onMsfPush:@"trpc.msg.olpush.OlPushService.MsgPush" msgBuffer:noAuthor pushExtraInfo:NSObject.new];
        timantirecall_check(session.timantirecall_pushCalls==before,@"missing display author cannot release a known other actor");
    });
    timantirecall_step(^{
        timantirecall_count(thirdRow,1,@"third-party recall marks self-authored message");
        [thirdRow removeFromSuperview];
        NSUInteger count=[timantirecall_sharedMarks() timantirecall_eventsForOwner:@"self_uid"].count;
        timantirecall_ownCaseForward(session,timantirecall_ownCasePacket(NO,138,nil,nil,18220),@"unknown private actor");
        timantirecall_ownCaseForward(session,timantirecall_ownCasePacket(YES,17,nil,@"self_uid",18221),@"unknown group actor");
        NSError *error=nil;
        timantirecall_check([timantirecall_settings() timantirecall_updateOptions:@{@"enabled":@NO} error:&error],@"own suite disables anti-recall");
        timantirecall_ownCaseForward(session,timantirecall_private(@"peer_a",@"self_uid",18222),@"private off");
        timantirecall_ownCaseForward(session,timantirecall_ownCasePacket(YES,17,@"third_actor",@"self_uid",18223),@"group off");
        timantirecall_check([timantirecall_settings() timantirecall_updateOptions:@{@"enabled":@YES} error:&error],@"own suite restores anti-recall");
        [session close:nil];
        timantirecall_check(session.timantirecall_closeCalls==1 && timantirecall_sessionOwner(session)==nil,@"own suite closes tracked session");
        timantirecall_ownCaseForward(session,timantirecall_private(@"peer_a",@"self_uid",18224),@"unknown session owner private");
        timantirecall_ownCaseForward(session,timantirecall_ownCasePacket(YES,17,@"third_actor",@"self_uid",18225),@"unknown session owner group");
        timantirecall_check([timantirecall_sharedMarks() timantirecall_eventsForOwner:@"self_uid"].count==count,@"unknown and off callbacks create no marks");
        [timantirecall_coverage addObject:@"own-recall-forwarded"];
    });
}
