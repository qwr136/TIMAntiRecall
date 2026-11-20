#import "TIMAntiRecallPacketSilent.h"
static void timantirecall_testSilentPackets(void) {
    __block TIMAntiRecallPreferencesController *settings;
    __block OCMsgRecord *first,*second,*third,*own;
    __block NSUInteger presents,loadings,prepares,claims,details;
    timantirecall_step(^{
        QQAccountsManager.GetInstance.currentUid=@"self_uid";
        timantirecall_check(timantirecall_installPacketMonitor() && timantirecall_installPacketMonitor(),@"original message monitor installs once for actual process execution");
        timantirecall_silentFixtureEnabled=YES;timantirecall_silentStarts=[NSMutableArray array];
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
        settings=[[TIMAntiRecallPreferencesController alloc] initWithOwner:@"self_uid" chat:nil];
        UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:settings];
        navigation.modalPresentationStyle=UIModalPresentationOverFullScreen;
        [timantirecall_window.rootViewController presentViewController:navigation animated:NO completion:nil];
        presents=timantirecall_silentPresents;loadings=timantirecall_silentLoadings;prepares=timantirecall_silentPrepares;
        claims=timantirecall_silentClaims;details=timantirecall_detailsShown;
        first=timantirecall_testPacket(1,9601,2,@"silent-unknown");
        second=timantirecall_testPacket(2,9602,3,@"silent-error");third=timantirecall_testPacket(1,9603,2,@"silent-success");
        timantirecall_silentHold=YES;
        QQWallet.GetInstance->_grabCompletionBlock=^(__unused NSDictionary *result,__unused NSError *error){};
        NSArray *batch=@[first];NSUInteger forwarded=timantirecall_ingressCalls;
        [NTMsgPushMonitorService recvMsgsWithRecords:batch];
        timantirecall_check(timantirecall_ingressCalls==forwarded+1 && timantirecall_forwardedRecords==batch,@"original batch is forwarded once with exact object identity");
        timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==0,@"occupied lower native wallet slot prevents overlap without dropping queued work");
        QQWallet.GetInstance->_grabCompletionBlock=nil;timantirecall_stepDelay=0.35;
    });
    timantirecall_step(^{
        timantirecall_check([timantirecall_silentStarts isEqual:@[first]],@"fresh ordinary packet routes on settings page without opening its chat");
        timantirecall_check(timantirecall_fixturePopup && !timantirecall_fixturePopup.view.window && !settings.presentedViewController,@"actual native popup remains off-window before its original open action");
        timantirecall_check(timantirecall_silentPresents==presents && timantirecall_silentLoadings==loadings,@"ordinary popup and loading original presenters were never called, not presented then closed");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[second,third,second]];timantirecall_stepDelay=0.2;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==1 && QQWalletGrapHBService.shareInstance.grapHBCallback!=nil,@"later packets wait only while original native slots are occupied");
        timantirecall_silentHold=NO;timantirecall_silentRelease(@{@"state":@9},nil);timantirecall_stepDelay=0.85;
    });
    timantirecall_step(^{
        timantirecall_check([timantirecall_silentStarts isEqual:@[first,second,third]],@"unknown and native error both release to next packet; duplicate is excluded");
        timantirecall_check(timantirecall_silentPrepares==prepares+3 && timantirecall_silentClaims==claims+3,@"each ordinary packet keeps native pre-open and native claim exactly once");
        timantirecall_check(timantirecall_silentPresents==presents && timantirecall_detailsShown==details && !settings.presentedViewController,@"no red packet modal, grey mask or details transition was presented");
        timantirecall_check(((OCMsgElement *)first.elements.firstObject).walletElement.grabbedAmount==0,@"next attempts do not wait for old message-model credit");
        timantirecall_check([timantirecall_findPacketToast().text isEqual:@"已领取 ¥1.23"],@"native successful recipient amount is shown instead of sent total");
        own=timantirecall_testPacket(1,9610,2,@"silent-own");own.senderUid=@"self_uid";
        [NTMsgPushMonitorService recvMsgsWithRecords:@[own]];timantirecall_stepDelay=0.2;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==3,@"own-sent opt-out is preserved");
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:YES owner:@"self_uid" error:NULL];
        OCMsgRecord *group=timantirecall_testPacket(2,9611,3,@"silent-own-group");group.senderUid=@"self_uid";
        [NTMsgPushMonitorService recvMsgsWithRecords:@[own,group]];timantirecall_stepDelay=0.65;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentStarts.count==5 && timantirecall_silentClaims==claims+5,@"own private and group packets still require both switches");
        OCMsgRecord *verify=timantirecall_testPacket(1,9620,2,@"silent-verify");
        OCMsgRecord *unsupported=timantirecall_testPacket(1,9621,2,@"silent-unsupported");
        OCMsgRecord *special=timantirecall_testPacket(2,9622,6,@"silent-command");
        OCMsgRecord *old=timantirecall_testPacket(1,9623,2,@"silent-old");old.msgTime-=3600;
        [NTMsgPushMonitorService recvMsgsWithRecords:@[verify,unsupported,special,old]];timantirecall_stepDelay=0.65;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentVerifications==1 && timantirecall_silentClaims==claims+5,@"native verification refuses the claim; unsupported native branch is not bypassed");
        timantirecall_check(timantirecall_silentStarts.count==7 && timantirecall_silentChecks>=12,@"old and command packets are excluded; native qualification queries remain intact");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_window.rootViewController dismissViewControllerAnimated:NO completion:nil];timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        QQWalletPreGrapHBResultViewController *manual=[QQWalletPreGrapHBResultViewController new];
        manual.grapHBData=[QQWalletGrapHBData new];manual.grapHBData.aioData=[QQWalletGrapHBAIOData new];manual.grapHBData.aioData.listId=@"manual-native";
        [QQWalletSceneManager presentTransparentViewController:manual];
        [QQWalletGrapHBService.shareInstance showLoading];timantirecall_stepDelay=0.15;
    });
    timantirecall_step(^{
        UIViewController *manual=timantirecall_window.rootViewController.presentedViewController;
        timantirecall_check(manual.view.window==timantirecall_window && timantirecall_silentPresents==presents+1 && timantirecall_silentLoadings==loadings+1,@"manual popup and unrelated native loading still present exactly once");
        [(QQWalletPreGrapHBResultViewController *)manual handleHBGrapResult:@{@"state":@0,@"recv_object":@{@"amount":@1}}];timantirecall_stepDelay=0.6;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_detailsShown==details+1,@"manual success retains original details completion");
        [timantirecall_coverage addObjectsFromArray:@[@"packet-monitor",@"packet-own-claim",@"packet-offscreen-on-settings",@"packet-native-slot-series",@"packet-no-detail",@"packet-amount-native-success",@"packet-no-popup-before-present",@"packet-native-preopen-token",@"packet-native-risk-preserved",@"packet-lower-slot-guard",@"packet-manual-window-preserved"]];
    });
}
static NSUInteger timantirecall_silentBackgroundUpdates,timantirecall_silentBackgroundPresents;
static void timantirecall_prepareSilentBackground(void) {
    timantirecall_silentBackgroundUpdates=timantirecall_silentUpdates;
    timantirecall_silentBackgroundPresents=timantirecall_silentPresents;
    timantirecall_silentHold=NO;
    [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
    [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
}
static void timantirecall_checkSilentBackground(UIScene *scene,NSUInteger attempt,dispatch_block_t done) {
    if(timantirecall_silentUpdates>=timantirecall_silentBackgroundUpdates+2 &&
       timantirecall_silentPacketReady(QQWalletRedPacketMsgService.class)) {
        timantirecall_check(UIApplication.sharedApplication.applicationState==UIApplicationStateBackground && scene.activationState==UISceneActivationStateBackground,
                           @"both native claim callbacks complete in real system background, before foreground resume");
        timantirecall_check(timantirecall_silentPresents==timantirecall_silentBackgroundPresents && !timantirecall_window.rootViewController.presentedViewController,
                           @"background callbacks never present a packet, grey mask or details controller");
        timantirecall_check(!timantirecall_findPacketToast(),@"no amount overlay is placed into another foreground app or queued for return");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_coverage addObjectsFromArray:@[@"packet-background-receive",@"packet-background-before-resume"]];
        done();return;
    }
    if(attempt>=30) {timantirecall_check(NO,@"background native receipt chain did not finish while process had execution time");done();return;}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{timantirecall_checkSilentBackground(scene,attempt+1,done);});
}
static void timantirecall_beginSilentBackground(UIScene *scene,dispatch_block_t done) {
    timantirecall_check(UIApplication.sharedApplication.applicationState==UIApplicationStateBackground,@"background ingress is not simulated with an active foreground app");
    OCMsgRecord *one=timantirecall_testPacket(1,9701,2,@"silent-background-private");
    OCMsgRecord *two=timantirecall_testPacket(2,9702,3,@"silent-background-group");
    [NTMsgPushMonitorService recvMsgsWithRecords:@[one,two,one]];
    timantirecall_checkSilentBackground(scene,0,done);
}
extern void timantirecall_expireSilentFixture(void);
static void timantirecall_testSilentLateReceipt(void) {
    timantirecall_step(^{
        timantirecall_silentHold=YES;
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        [NTMsgPushMonitorService recvMsgsWithRecords:@[timantirecall_testPacket(1,9681,2,@"silent-late-success")]];
        timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        timantirecall_expireSilentFixture();
        timantirecall_check(QQWalletGrapHBService.shareInstance.grapHBCallback!=nil && !timantirecall_silentPacketReady(QQWalletRedPacketMsgService.class),@"expired wait preserves an outstanding native claim and does not free its slots");
        timantirecall_silentHold=NO;
        timantirecall_silentRelease(@{@"state":@0,@"recv_object":@{@"amount":@7}},nil);timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_silentPacketReady(QQWalletRedPacketMsgService.class) && [timantirecall_findPacketToast().text isEqual:@"已领取 ¥0.07"],@"late native success still confirms its exact amount and releases to the next packet");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_coverage addObject:@"packet-late-receipt"];
    });
}
static void timantirecall_testSilentManualContention(void) {
    __block NSUInteger pre,claims,presents,details,manualCallbacks;
    timantirecall_step(^{
        pre=timantirecall_silentPrepares;claims=timantirecall_silentClaims;presents=timantirecall_silentPresents;details=timantirecall_detailsShown;manualCallbacks=0;
        timantirecall_silentHold=YES;
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        [NTMsgPushMonitorService recvMsgsWithRecords:@[timantirecall_testPacket(1,9685,2,@"silent-manual-contention")]];
        timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        void (^slot)(NSDictionary *,NSError *)=QQWalletGrapHBService.shareInstance.grapHBCallback;
        [QQWallet.GetInstance grabHB:nil params:timantirecall_silentNativeEnvelope(@"manual-priority") completion:^(__unused NSDictionary *result,__unused NSError *error){manualCallbacks++;}];
        timantirecall_check(slot && QQWalletGrapHBService.shareInstance.grapHBCallback==slot && timantirecall_silentPrepares==pre+1,@"manual open waits instead of overwriting the invisible automatic claim's callback");
        timantirecall_silentHold=NO;timantirecall_silentRelease(@{@"state":@0,@"recv_object":@{@"amount":@21}},nil);
        timantirecall_stepDelay=0.25;
    });
    timantirecall_step(^{
        UIViewController *manual=timantirecall_window.rootViewController.presentedViewController;
        timantirecall_check(timantirecall_silentPrepares==pre+2 && timantirecall_silentPresents==presents+1 && manual.view.window==timantirecall_window,@"deferred manual request resumes its unchanged native presenter after auto slots release");
        [(QQWalletPreGrapHBResultViewController *)manual onOpenButtonClick:((QQWalletPreGrapHBResultViewController *)manual).grapHBView];
        timantirecall_stepDelay=0.5;
    });
    timantirecall_step(^{
        timantirecall_check(manualCallbacks==1 && timantirecall_silentClaims==claims+2 && timantirecall_detailsShown==details+1,@"manual continuation and details complete once without losing either native receipt");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_coverage addObject:@"packet-manual-slot-priority"];
    });
}
static void timantirecall_testSilentNativeEnvelope(void) {
    NSArray<NSString *> *shapes=@[@"nested",@"flat",@"not-dictionary",@"bad-extra",@"missing-bill",@"numeric-bill",@"mismatched-bill",@"unsupported",@"no-preopen",@"native-error"];
    NSArray<NSString *> *phases=@[@"redpack-silent-receipt-confirmed",@"redpack-silent-reject-envelope",@"redpack-silent-reject-envelope",@"redpack-silent-reject-envelope",@"redpack-silent-reject-bill-type",@"redpack-silent-reject-bill-type",@"redpack-silent-reject-bill-mismatch",@"redpack-silent-reject-legacy-route",@"redpack-silent-reject-no-preopen",@"redpack-silent-native-error"];
    for(NSUInteger i=0;i<shapes.count;i++) {
        NSString *shape=shapes[i],*expected=phases[i];
        NSString *bill=[NSString stringWithFormat:@"envelope-%@",shape];
        if([shape isEqual:@"no-preopen"])bill=@"envelope-nopre";
        if([shape isEqual:@"native-error"])bill=@"envelope-error";
        id envelope=timantirecall_silentNativeEnvelope(bill);
        if([shape isEqual:@"flat"])envelope=@{@"listid":bill};
        else if([shape isEqual:@"not-dictionary"])envelope=@"not-an-envelope";
        else if([shape isEqual:@"bad-extra"])envelope=@{@"extra_data":@123,@"listid":bill};
        else if([shape isEqual:@"missing-bill"])envelope=@{@"extra_data":@{},@"listid":bill};
        else if([shape isEqual:@"numeric-bill"])envelope=@{@"extra_data":@{@"listid":@123}};
        else if([shape isEqual:@"mismatched-bill"])envelope=@{@"extra_data":@{@"listid":@"different-native-bill"},@"listid":bill};
        __block NSUInteger callbacks=0,prepares=0,claims=0,presents=0;
        __block NSString *phase=nil,*amount=nil;
        BOOL native=[shape isEqual:@"nested"] || [shape isEqual:@"native-error"];
        timantirecall_step(^{
            timantirecall_check(timantirecall_silentPacketReady(QQWalletRedPacketMsgService.class),@"envelope case starts only after all preceding native slots are idle");
            prepares=timantirecall_silentPrepares;claims=timantirecall_silentClaims;presents=timantirecall_silentPresents;
            timantirecall_silentForwardedEnvelope=nil;
            BOOL began=timantirecall_beginSilentPacket(QQWalletRedPacketMsgService.class,bill,^BOOL(void){return YES;},^(NSString *resultPhase,NSString *text){
                callbacks++;phase=resultPhase;amount=text;
            },^(TIMAntiRecallSilentReceipt completion){
                [QQWallet.GetInstance grabHB:nil params:envelope completion:completion];
            });
            timantirecall_check(began,@"envelope guard runs inside the original native entry context");timantirecall_stepDelay=0.3;
        });
        timantirecall_step(^{
            timantirecall_check(callbacks==1 && [phase isEqual:expected],@"local envelope rejection has its exact fixed reason, not a generic Wallet error");
            timantirecall_check(timantirecall_silentPrepares==prepares+(native?1:0) && timantirecall_silentClaims==claims+(native?1:0),@"only an authorized nested same-bill envelope reaches native pre-open and claim");
            timantirecall_check(timantirecall_silentPresents==presents,@"native envelope validation never introduces a red packet window");
            timantirecall_check(native?timantirecall_silentForwardedEnvelope==envelope:timantirecall_silentForwardedEnvelope==nil,@"original native start receives the exact envelope object unchanged, or is not called");
            timantirecall_check([shape isEqual:@"nested"]?[amount isEqual:@"已领取 ¥1.23"]:amount==nil,@"only the successful nested native receipt supplies an amount");
            timantirecall_check(timantirecall_silentPacketReady(QQWalletRedPacketMsgService.class),@"a rejected or completed envelope leaves all native slots available for later packets");
        });
    }
    timantirecall_step(^{
        timantirecall_silentForwardedEnvelope=nil;
        [timantirecall_coverage addObjectsFromArray:@[@"packet-native-parameter-envelope",@"packet-native-local-rejection"]];
    });
}
