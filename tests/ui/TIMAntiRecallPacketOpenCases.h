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
