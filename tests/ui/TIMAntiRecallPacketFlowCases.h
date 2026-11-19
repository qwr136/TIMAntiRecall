// Real UIKit return effects and serial queue; these are not actual TIM tests.
static void timantirecall_testPacketResultAndQueue(void) {
    __block NSUInteger routes,opens,closes;
    __block UIViewController *origin,*savedRoot;
    __block UINavigationController *navigation;
    __block OCMsgRecord *first,*second;
    for(NSNumber *kind in @[@3,@4,@5,@6,@7]) {
        timantirecall_step(^{
            origin=timantirecall_window.rootViewController;
            if(kind.intValue==7) {
                savedRoot=origin;origin=[UIViewController new];
                navigation=[[UINavigationController alloc] initWithRootViewController:origin];
                [navigation setNavigationBarHidden:YES animated:NO];
                timantirecall_window.rootViewController=navigation;
                [navigation.view layoutIfNeeded];
            }
            timantirecall_receiptMode=kind.intValue;routes=timantirecall_walletCalls;
            [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
            first=timantirecall_testPacket(1,8400+kind.longLongValue,2,[NSString stringWithFormat:@"result-%@",kind]);
            [NTMsgPushMonitorService recvMsgsWithRecords:@[first]];
            timantirecall_stepDelay=1.8;
        });
        timantirecall_step(^{
            BOOL blocked=kind.intValue==4 || kind.intValue==5 || kind.intValue==6;
            timantirecall_check(timantirecall_walletCalls==routes+1,@"native route forwarded once for real result-page test");
            timantirecall_check(((OCMsgElement *)first.elements.firstObject).walletElement.grabbedAmount==0,@"result-page fallback does not mutate original zero receipt model");
            if(blocked) {
                timantirecall_check(timantirecall_resultController.viewIfLoaded.window==timantirecall_window,
                    kind.intValue==4?@"native error vetoes even positive-looking result UI":kind.intValue==5?@"wrong-bill result is never returned":@"success state without positive received amount is not sufficient");
                [origin dismissViewControllerAnimated:NO completion:nil];
            }else {
                timantirecall_check(!timantirecall_resultController.viewIfLoaded.window && !origin.presentedViewController,
                    @"correlated native receipt returns actual detail page with unchanged source model");
                if(kind.intValue==7)timantirecall_check(navigation.topViewController==origin,@"push result returns exactly one controller to original navigation prefix");
                timantirecall_check(!timantirecall_hasPendingPacketUI(),@"queue lock releases only after real return effect is observed");
            }
            [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
            if(navigation) {
                timantirecall_window.rootViewController=savedRoot;navigation=nil;savedRoot=nil;
            }
            timantirecall_openFixture=nil;first=nil;timantirecall_walletRecord=nil;timantirecall_forwardedRecords=nil;
            timantirecall_receiptMode=0;
        });
    }
    timantirecall_step(^{
        routes=timantirecall_walletCalls;opens=timantirecall_openButtonCalls;closes=timantirecall_closeButtonCalls;
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        first=timantirecall_testPacket(1,8501,2,@"queue-one");second=timantirecall_testPacket(2,8502,3,@"queue-two");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[first,second,second]];
        timantirecall_stepDelay=1.9;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==routes+2 && timantirecall_walletRecord==second,@"two same-batch packets dequeue in arrival order without dropping second");
        timantirecall_check(timantirecall_openButtonCalls==opens+2 && timantirecall_closeButtonCalls==closes+2,@"both queued packets open and close once with duplicate excluded");
        routes=timantirecall_walletCalls;timantirecall_receiptMode=1;
        first=timantirecall_testPacket(1,8503,2,@"queue-busy-first");second=timantirecall_testPacket(1,8504,2,@"queue-busy-second");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[first]];
        [NTMsgPushMonitorService recvMsgsWithRecords:@[second]];
        timantirecall_stepDelay=0.7;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==routes+1 && timantirecall_hasPendingPacketUI(),@"second delivery waits while first native receive UI is unresolved");
        ((OCMsgElement *)first.elements.firstObject).walletElement.grabbedAmount=1;
        timantirecall_receiptMode=0;timantirecall_stepDelay=2.2;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==routes+2 && timantirecall_walletRecord==second,@"busy queued packet resumes after first receipt and actual close");
        routes=timantirecall_walletCalls;timantirecall_receiptMode=1;
        first=timantirecall_testPacket(1,8505,2,@"queue-manual-first");second=timantirecall_testPacket(2,8506,3,@"queue-manual-second");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[first,second]];timantirecall_stepDelay=0.7;
    });
    timantirecall_step(^{
        [timantirecall_openFixture.timantirecall_closeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        timantirecall_stepDelay=0.6;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==routes+1,@"manual takeover cancels queued packet instead of reopening native UI");
        routes=timantirecall_walletCalls;opens=timantirecall_openButtonCalls;timantirecall_receiptMode=8;
        first=timantirecall_testPacket(1,8507,2,@"queue-error-without-page");second=timantirecall_testPacket(1,8508,2,@"queue-after-error");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[first,second]];timantirecall_stepDelay=1.8;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==routes+2 && timantirecall_walletRecord==second,@"route error without UI releases lock and second packet still routes once");
        timantirecall_check(timantirecall_openButtonCalls==opens+1,@"failed first packet is not retried or auto-opened");
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
        timantirecall_receiptMode=0;first=nil;second=nil;origin=nil;
        timantirecall_openFixture=nil;timantirecall_walletRecord=nil;timantirecall_forwardedRecords=nil;
        [timantirecall_coverage addObjectsFromArray:@[@"packet-result-return",@"packet-native-response",@"packet-queue-batch",@"packet-queue-busy",@"packet-queue-manual"]];
    });
}
