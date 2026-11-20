#import "TIMAntiRecallPacketOpen.h"

static UIButton *timantirecall_guardButton(NSString *title,id target,CGFloat y) {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];button.frame=CGRectMake(80,y,120,60);
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:target action:@selector(timantirecall_open:) forControlEvents:UIControlEventTouchUpInside];
    [timantirecall_window.rootViewController.view addSubview:button];return button;
}
static void timantirecall_testPacketOpenGuards(void) {
    __block UIButton *first,*second;
    __block TIMAntiRecallPacketOpenFixture *target;
    __block NSUInteger before;
    __block BOOL valid;
    timantirecall_step(^{
        before=timantirecall_openButtonCalls;target=[TIMAntiRecallPacketOpenFixture new];
        first=timantirecall_guardButton(@"開",target,100);
        timantirecall_beginPacketOpen(timantirecall_window.rootViewController,QQWalletRedPacketMsgService.class,^{return YES;});
        second=timantirecall_guardButton(@"支付",target,180);
        timantirecall_stepDelay=0.5;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_openButtonCalls==before,@"does not click pre-existing open or payment control");
        [first removeFromSuperview];[second removeFromSuperview];valid=YES;
        timantirecall_beginPacketOpen(timantirecall_window.rootViewController,QQWalletRedPacketMsgService.class,^{return valid;});
        first=timantirecall_guardButton(@"開",target,100);valid=NO;
        timantirecall_stepDelay=0.4;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_openButtonCalls==before,@"stale account/foreground/setting token prevents opening");
        [first removeFromSuperview];
        timantirecall_beginPacketOpen(timantirecall_window.rootViewController,QQWalletRedPacketMsgService.class,^{return YES;});
        first=timantirecall_guardButton(@"開",target,100);second=timantirecall_guardButton(@"开红包",target,180);
        timantirecall_stepDelay=0.5;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_openButtonCalls==before,@"ambiguous multiple native open buttons are not clicked");
        [first removeFromSuperview];[second removeFromSuperview];
        timantirecall_beginPacketOpen(timantirecall_window.rootViewController,QQWalletRedPacketMsgService.class,^{return YES;});
        first=timantirecall_guardButton(@"開",target,100);
        [first sendActionsForControlEvents:UIControlEventTouchUpInside];
        timantirecall_stepDelay=0.5;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_openButtonCalls==before+1,@"manual action forwards exactly once and cancels pending automatic press");
        [first removeFromSuperview];first=nil;second=nil;target=nil;
        [timantirecall_coverage addObject:@"packet-open-guards"];
    });
}

static void __attribute__((unused)) timantirecall_testReceiptCloseGuards(void) {
    for(NSNumber *mode in @[@1,@2]) {
        __block NSUInteger opens,closes;
        timantirecall_step(^{
            opens=timantirecall_openButtonCalls;closes=timantirecall_closeButtonCalls;
            timantirecall_receiptMode=mode.intValue;
            [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
            OCMsgRecord *packet=timantirecall_testPacket(1,8200+mode.longLongValue,2,[NSString stringWithFormat:@"guard-%@",mode]);
            [NTMsgPushMonitorService recvMsgsWithRecords:@[packet]];
            timantirecall_stepDelay=1.4;
        });
        timantirecall_step(^{
            timantirecall_check(timantirecall_openButtonCalls==opens+1,@"receipt guard still opens the native image button through WeakProxy");
            timantirecall_check(timantirecall_closeButtonCalls==closes && timantirecall_openFixture.timantirecall_overlay.window,
                               mode.intValue==1?@"nil-error callback without model receipt does not close":@"native error vetoes close even if model amount became positive");
            timantirecall_check(timantirecall_hasPendingPacketUI(),@"owned pending receive UI prevents overlapping automatic routes");
            [timantirecall_openFixture.timantirecall_closeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            timantirecall_check(timantirecall_closeButtonCalls==closes+1 && !timantirecall_hasPendingPacketUI(),@"user close forwards once and cancels pending auto-close");
            [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
            timantirecall_openFixture=nil;timantirecall_forwardedRecords=nil;timantirecall_walletRecord=nil;
            timantirecall_receiptMode=0;
        });
    }
    timantirecall_step(^{[timantirecall_coverage addObject:@"packet-close-confirmation"];});
}

static OCMsgRecord *timantirecall_selfSentPacket(int chat,int64_t sequence,int32_t type,NSString *bill) {
    OCMsgRecord *record=timantirecall_testPacket(chat,sequence,type,bill);record.senderUid=@"self_uid";return record;
}
static void __attribute__((unused)) timantirecall_testSelfSentPackets(void) {
    __block NSUInteger walletBefore,openBefore,closeBefore;
    timantirecall_step(^{
        walletBefore=timantirecall_walletCalls;openBefore=timantirecall_openButtonCalls;closeBefore=timantirecall_closeButtonCalls;
        QQAccountsManager.GetInstance.currentUid=@"self_uid";
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"self_uid" error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
        timantirecall_check(![timantirecall_settings() timantirecall_claimOwnRedPackets],@"self-sent claims require explicit separate opt-in");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[timantirecall_selfSentPacket(1,8301,2,@"self-off")]];
        timantirecall_stepDelay=0.45;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==walletBefore,@"self-sent private packet remains skipped while opt-out");
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:YES owner:@"self_uid" error:NULL];
        [NTMsgPushMonitorService recvMsgsWithRecords:@[timantirecall_selfSentPacket(1,8302,2,@"self-private-on")]];
        timantirecall_stepDelay=1.6;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==walletBefore+1,@"own private packet routes only after separate switch is enabled");
        timantirecall_check(timantirecall_openButtonCalls==openBefore+1 && timantirecall_closeButtonCalls==closeBefore+1,@"own private receipt opens once then closes its replacement control");
        [NTMsgPushMonitorService recvMsgsWithRecords:@[timantirecall_selfSentPacket(2,8303,3,@"self-group-on")]];
        timantirecall_stepDelay=1.6;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_walletCalls==walletBefore+2,@"own group packet routes with separate opt-in");
        timantirecall_check(timantirecall_openButtonCalls==openBefore+2 && timantirecall_closeButtonCalls==closeBefore+2,@"own group receipt closes the newly discovered close control");
        [timantirecall_settings() timantirecall_setPacketOption:@"claimOwn" enabled:NO owner:@"self_uid" error:NULL];
        [timantirecall_settings() timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"self_uid" error:NULL];
    });
    timantirecall_step(^{[timantirecall_coverage addObject:@"packet-own-claim"];});
}

@interface TIMAntiRecallBadProxyTarget : NSObject
- (BOOL)openButtonClick;
@end
@implementation TIMAntiRecallBadProxyTarget
- (BOOL)openButtonClick {timantirecall_openButtonCalls++;return NO;}
@end
static void timantirecall_testProxyRejections(void) {
    __block WeakProxy *proxy;
    __block id receiver;
    __block UIButton *button;
    __block NSUInteger before;
    for(NSNumber *kind in @[@0,@1]) {
        timantirecall_step(^{
            before=timantirecall_openButtonCalls;
            receiver=kind.boolValue?[TIMAntiRecallBadProxyTarget new]:nil;
            proxy=[WeakProxy new];proxy.target=receiver;
            timantirecall_beginPacketOpen(timantirecall_window.rootViewController,QQWalletRedPacketMsgService.class,^BOOL(void){return YES;});
            button=[UIButton buttonWithType:UIButtonTypeSystem];button.frame=CGRectMake(80,140,120,70);
            [button addTarget:proxy action:@selector(openButtonClick) forControlEvents:UIControlEventTouchUpInside];
            [timantirecall_window.rootViewController.view addSubview:button];
        timantirecall_stepDelay=0.6;
        });
        timantirecall_step(^{
            timantirecall_check(timantirecall_openButtonCalls==before,kind.boolValue?@"proxy dummy void signature cannot hide actual BOOL action ABI":@"expired weak proxy receiver is not messaged");
            [button removeFromSuperview];button=nil;proxy=nil;receiver=nil;
        });
    }
    timantirecall_step(^{[timantirecall_coverage addObject:@"packet-proxy-rejections"];});
}
