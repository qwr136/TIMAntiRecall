// Verify only plugin-added dispatch latency, not network/receipt elapsed time.
static void timantirecall_testFastPacketIngress(void) {
    __block NSUInteger start,prepares,presents,forwarded;
    __block OCMsgRecord *delayedPrivate,*delayedGroup;
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
        timantirecall_silentHold=YES;
        [NTMsgPushMonitorService recvMsgsWithRecords:batch];
        timantirecall_check(timantirecall_ingressCalls==forwarded+1 && timantirecall_forwardedRecords==batch,@"fast ingress preserves the whole original batch and forwards it exactly once");
        timantirecall_check(timantirecall_silentPrepares==prepares+1 && timantirecall_silentStarts.count==start+1 &&
                           timantirecall_silentStarts.lastObject==delayedPrivate,@"idle main-thread ingress reaches the original route before the receiving call returns, including a packet after item 64");
        timantirecall_stepDelay=0.15;
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
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_coverage addObjectsFromArray:@[@"packet-fast-main-ingress",@"packet-delayed-live-window",@"packet-wide-message-batch"]];
    });
}

// These packets are already present in two normal NT message view models when
// binding occurs. The test does not call an unverified kernel history API.
static void timantirecall_testLoadedRecentPackets(void) {
    __block TIMAntiRecallTestBaseView *privateRow,*groupRow,*oldRow,*creditedRow,*expiredRow;
    __block OCMsgRecord *privateOld,*groupOld,*liveGroup,*tooOld,*alreadyCredited,*expired;
    __block NSUInteger start,prepares,presents,forwarded;
    timantirecall_step(^{
        start=timantirecall_silentStarts.count;prepares=timantirecall_silentPrepares;
        presents=timantirecall_silentPresents;forwarded=timantirecall_ingressCalls;
        timantirecall_silentHold=YES;
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
        privateOld=timantirecall_testPacket(1,9910,2,@"loaded-old-private");privateOld.msgTime-=60;privateOld.isOnlineMsg=NO;privateOld.isImportMsg=YES;
        groupOld=timantirecall_testPacket(2,9911,3,@"loaded-old-group");groupOld.msgTime-=75;groupOld.isOnlineMsg=NO;groupOld.isImportMsg=YES;
        tooOld=timantirecall_testPacket(1,9912,2,@"loaded-too-old");tooOld.msgTime-=120;
        alreadyCredited=timantirecall_testPacket(1,9913,2,@"loaded-credited");((OCMsgElement *)alreadyCredited.elements.firstObject).walletElement.grabbedAmount=1;
        expired=timantirecall_testPacket(1,9914,2,@"loaded-expired");expired.msgTime-=90001;
        privateRow=timantirecall_row(timantirecall_window.rootViewController.view,CGRectMake(8,80,300,70));
        groupRow=timantirecall_row(timantirecall_window.rootViewController.view,CGRectMake(8,155,300,70));
        oldRow=timantirecall_row(timantirecall_window.rootViewController.view,CGRectMake(8,230,300,70));
        creditedRow=timantirecall_row(timantirecall_window.rootViewController.view,CGRectMake(8,305,300,70));
        expiredRow=timantirecall_row(timantirecall_window.rootViewController.view,CGRectMake(8,380,300,70));
        // This exercises only the exact original OCMsgRecord already bound to real NT message-cell models.
        [privateRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:privateOld]];
        [groupRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:groupOld]];
        [oldRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:tooOld]];
        [creditedRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:alreadyCredited]];
        [expiredRow bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_message:expired]];
        timantirecall_stepDelay=0.16;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==start+1 && timantirecall_silentStarts[start]==privateOld &&
                           QQWalletGrapHBService.shareInstance.grapHBCallback!=nil,
                           @"a recent already-loaded old private packet enters the original Wallet flow without a popup");
        timantirecall_check(((OCMsgElement *)tooOld.elements.firstObject).walletElement.grabbedAmount==0 &&
                           ((OCMsgElement *)alreadyCredited.elements.firstObject).walletElement.grabbedAmount>0,
                           @"expired and already-credited old candidates remain untouched");
        // The same bound OCMsgRecord may later reach the live callback; promote it rather than queue it twice.
        liveGroup=groupOld;liveGroup.isOnlineMsg=YES;liveGroup.isImportMsg=NO;
        NSArray *batch=@[liveGroup];[NTMsgPushMonitorService recvMsgsWithRecords:batch];
        timantirecall_check(timantirecall_ingressCalls==forwarded+1 && timantirecall_forwardedRecords==batch,
                           @"live same-bill callback is forwarded once without changing original records");
        timantirecall_check(timantirecall_silentStarts.count==start+1 && QQWalletGrapHBService.shareInstance.grapHBCallback!=nil,
                           @"same-bill live promotion never overwrites the occupied Wallet callback");
        timantirecall_silentHold=NO;timantirecall_silentRelease(@{@"state":@9},nil);timantirecall_stepDelay=0.30;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==start+2 && timantirecall_silentStarts[start+1]==groupOld,
                           @"the naturally loaded old group packet continues after the preceding native callback releases");
        timantirecall_silentRelease(@{@"state":@9},nil);timantirecall_stepDelay=0.30;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==start+2 && timantirecall_silentPrepares==prepares+2,
                           @"loaded old candidates are identity-deduplicated and each receives one native pre-open attempt");
        timantirecall_check(timantirecall_silentPresents==presents && !timantirecall_hasPendingPacketUI(),
                           @"passive loaded-message observation never opens a popup or starts a guessed history query");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [privateRow removeFromSuperview];[groupRow removeFromSuperview];[oldRow removeFromSuperview];[creditedRow removeFromSuperview];[expiredRow removeFromSuperview];
        [timantirecall_coverage addObjectsFromArray:@[@"packet-loaded-old-private-group",@"packet-loaded-live-promotion",@"packet-loaded-bounds-claimed-expired"]];
    });
}
