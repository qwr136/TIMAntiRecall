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

static void timantirecall_testReceiptCloseGuards(void) {
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
            timantirecall_stepDelay=0.45;
        });
        timantirecall_step(^{
            timantirecall_check(timantirecall_openButtonCalls==before,kind.boolValue?@"proxy dummy void signature cannot hide actual BOOL action ABI":@"expired weak proxy receiver is not messaged");
            [button removeFromSuperview];button=nil;proxy=nil;receiver=nil;
        });
    }
    timantirecall_step(^{[timantirecall_coverage addObject:@"packet-proxy-rejections"];});
}
