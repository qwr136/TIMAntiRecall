// Verify only plugin-added dispatch latency, not network/receipt elapsed time.
static void timantirecall_testFastPacketIngress(void) {
    __block NSUInteger start,prepares,presents,forwarded;
    __block OCMsgRecord *delayedPrivate,*delayedGroup;
    __block NSMutableArray *historicalRows;
    __block NSUInteger settledStarts,settledPrepares;
    timantirecall_step(^{
        start=timantirecall_silentStarts.count;prepares=timantirecall_silentPrepares;
        presents=timantirecall_silentPresents;forwarded=timantirecall_ingressCalls;
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
        NSMutableArray *batch=[NSMutableArray array];
        for(NSUInteger i=0;i<96;i++)[batch addObject:timantirecall_record(1,9800+i,@"peer_a",7001)];
        delayedPrivate=timantirecall_testPacket(1,9901,2,@"fast-delayed-private");delayedPrivate.msgTime-=120;
        delayedGroup=timantirecall_testPacket(2,9902,3,@"fast-delayed-group");delayedGroup.msgTime-=240;
        OCMsgRecord *tooOld=timantirecall_testPacket(1,9903,2,@"fast-unknown-old");tooOld.msgTime-=3600;
        OCMsgRecord *imported=timantirecall_testPacket(1,9904,2,@"fast-imported");imported.isImportMsg=YES;
        OCMsgRecord *future=timantirecall_testPacket(1,9905,2,@"fast-future");future.msgTime+=20;
        [batch addObjectsFromArray:@[delayedPrivate,delayedGroup,delayedPrivate,tooOld,imported,future]];
        [NTMsgPushMonitorService recvMsgsWithRecords:batch];
        timantirecall_check(timantirecall_ingressCalls==forwarded+1 && timantirecall_forwardedRecords==batch,@"fast ingress preserves the whole original batch and forwards it exactly once");
        timantirecall_check(timantirecall_silentPrepares==prepares && timantirecall_silentStarts.count==start,@"native claim waits until the original receive callback has returned");
        timantirecall_silentHold=YES;
        timantirecall_stepDelay=0.16;
    });
    timantirecall_step(^{
        timantirecall_check(QQWalletGrapHBService.shareInstance.grapHBCallback!=nil &&
                           timantirecall_silentStarts.count==start+1,@"no speed optimization overrides an occupied native claim callback");
        timantirecall_silentHold=NO;
        timantirecall_silentRelease(@{@"state":@9},nil);
        timantirecall_stepDelay=0.55;
    });
    timantirecall_step(^{
        NSArray *newStarts=[timantirecall_silentStarts subarrayWithRange:NSMakeRange(start,timantirecall_silentStarts.count-start)];
        timantirecall_check([newStarts isEqual:@[delayedPrivate,delayedGroup]],@"two- and four-minute delayed live packets are recognized; duplicate, imported, future and unknown old packets are excluded");
        timantirecall_check(timantirecall_silentPresents==presents && timantirecall_silentPrepares==prepares+2,@"faster recognition retains the no-popup native pre-open path for both live chats");
        settledStarts=timantirecall_silentStarts.count;settledPrepares=timantirecall_silentPrepares;
        // Replaying accepted live records is not permission to submit them again.
        [NTMsgPushMonitorService recvMsgsWithRecords:@[delayedPrivate,delayedGroup,delayedPrivate]];
        historicalRows=[NSMutableArray array];
        for(NSUInteger index=0;index<2;index++) {
            OCMsgRecord *old=timantirecall_testPacket(index?2:1,9950+index,index?3:2,index?@"history-claimed":@"history-unknown-zero");
            old.msgTime-=3600;old.isOnlineMsg=NO;old.isImportMsg=YES;
            ((OCMsgElement *)old.elements.firstObject).walletElement.grabbedAmount=index?123:0;
            TIMAntiRecallTestBaseView *row=timantirecall_row(timantirecall_window.rootViewController.view,CGRectMake(8,100+100*index,300,88));
            timantirecall_check([row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:old]],@"ordinary historical row still binds after removing the packet observer");
            [row setNeedsLayout];[row layoutIfNeeded];[historicalRows addObject:row];
        }
        timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==settledStarts && timantirecall_silentPrepares==settledPrepares,@"browsing claimed or unknown-zero old records and replaying live records never retriggers native pre-open");
        for(UIView *row in historicalRows)[row removeFromSuperview];historicalRows=nil;
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_coverage addObjectsFromArray:@[@"packet-fast-main-ingress",@"packet-delayed-live-window",@"packet-wide-message-batch",@"packet-no-history-auto-attempt",@"packet-realtime-replay-dedup"]];
    });
}
