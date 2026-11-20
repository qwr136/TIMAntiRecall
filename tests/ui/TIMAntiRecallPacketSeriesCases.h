// No packet chat or rendered row participates in this test.
static void timantirecall_testForegroundPacketSeries(void) {
    __block TIMAntiRecallPreferencesController *settings;
    __block OCMsgRecord *first,*second,*third;
    __block NSUInteger opens,closes,details;
    __block UILabel *successToast;
    timantirecall_step(^{
        opens=timantirecall_nativePopupOpens;closes=timantirecall_nativePopupCloses;details=timantirecall_detailsShown;
        timantirecall_check(!timantirecall_hasPendingPacketUI(),@"standalone probe without an open popup or bill does not own the next route");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        settings=[[TIMAntiRecallPreferencesController alloc] initWithOwner:@"self_uid" chat:nil];
        UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:settings];
        navigation.modalPresentationStyle=UIModalPresentationOverFullScreen;
        [timantirecall_window.rootViewController presentViewController:navigation animated:NO completion:nil];
        timantirecall_seriesStarts=[NSMutableArray array];timantirecall_seriesEnabled=YES;
        first=timantirecall_testPacket(1,8401,2,@"series-one");
        second=timantirecall_testPacket(2,8402,3,@"series-two");
        third=timantirecall_testPacket(1,8403,2,@"series-three");
        QQWalletGrapHBService.shareInstance.preGrapHBCallback=^(__unused NSDictionary *result,__unused NSError *error){};
        [NTMsgPushMonitorService recvMsgsWithRecords:@[first]];timantirecall_stepDelay=0.35;
    });
    timantirecall_step(^{
        timantirecall_check(!timantirecall_seriesStarts.count,@"pre-open slot held by another route prevents overlap without dropping packet");
        QQWalletGrapHBService.shareInstance.preGrapHBCallback=nil;timantirecall_stepDelay=0.65;
    });
    timantirecall_step(^{
        timantirecall_check([timantirecall_seriesStarts isEqual:@[first]] && timantirecall_fixtureHost==settings,@"unseen packet routes on actual settings page rather than its chat");
        timantirecall_check(timantirecall_nativePopupOpens==opens+1 && QQWalletGrapHBService.shareInstance.grapHBCallback!=nil,@"first native open is in flight");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[second,third,second]];
        timantirecall_stepDelay=0.30;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_seriesStarts.count==1 && timantirecall_nativePopupCloses==closes,@"later receipts wait only while first wallet slot is actually occupied");
        timantirecall_check(!timantirecall_findPacketToast(),@"in-flight or unconfirmed receipts never show a claimed amount");
        // Deliberately no business result, no amount update and no route callback.
        QQWalletGrapHBService.shareInstance.grapHBCallback=nil;
        timantirecall_stepDelay=2.1;
    });
    timantirecall_step(^{
        timantirecall_check([timantirecall_seriesStarts isEqual:@[first,second,third]],@"unknown result then native error both advance the queue, duplicates excluded");
        timantirecall_check(((OCMsgElement *)first.elements.firstObject).walletElement.grabbedAmount==0,@"no earlier credit is required for later attempts");
        timantirecall_check(timantirecall_nativePopupOpens==opens+3 && timantirecall_nativePopupCloses==closes+2,@"each packet opens once and only the two released leftover popups retire");
        timantirecall_check(timantirecall_detailsShown==details && !settings.presentedViewController && settings.viewIfLoaded.window==timantirecall_window,
                           @"same-bill native success keeps UIKit dismissal and never opens the details page");
        successToast=timantirecall_findPacketToast();
        timantirecall_check([successToast.text isEqual:@"已领取 ¥1.23"],@"native same-bill success shows received amount, never total sent amount");
        // Manual/unarmed success must still execute native details completion.
        QQWalletPreGrapHBResultViewController *manual=[QQWalletPreGrapHBResultViewController new];
        manual.grapHBData=[QQWalletGrapHBData new];manual.grapHBData.aioData=[QQWalletGrapHBAIOData new];manual.grapHBData.aioData.listId=@"manual";
        manual.modalPresentationStyle=UIModalPresentationOverFullScreen;
        [settings presentViewController:manual animated:NO completion:^{
            [manual handleHBGrapResult:@{@"state":@0,@"recv_object":@{@"amount":@1}}];
        }];
        timantirecall_stepDelay=0.8;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_detailsShown==details+1,@"manual success retains its native details transition");
        timantirecall_check(successToast && timantirecall_findPacketToast()==successToast,@"manual receipt does not create or refresh an automatic-claim toast");
        [timantirecall_coverage addObject:@"packet-amount-native-success"];
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        timantirecall_seriesEnabled=NO;timantirecall_seriesStarts=nil;timantirecall_forwardedRecords=nil;timantirecall_walletRecord=nil;
        [timantirecall_coverage addObjectsFromArray:@[@"packet-offscreen-on-settings",@"packet-native-slot-series",@"packet-no-detail"]];
        timantirecall_stepDelay=0.3;
    });
}
