#import "TIMAntiRecallPacketToast.h"
static UILabel *timantirecall_findPacketToast(void) {
    for(UIView *view in timantirecall_window.subviews)
        if([view.accessibilityIdentifier isEqual:@"TIMAntiRecallPacketAmountToast"] && [view isKindOfClass:UILabel.class])return (UILabel *)view;
    return nil;
}
static void timantirecall_testPacketAmountToast(void) {
    timantirecall_step(^{
        NSDictionary *examples=@{@1:@"已领取 ¥0.01",@10:@"已领取 ¥0.10",@105:@"已领取 ¥1.05",@10000:@"已领取 ¥100.00",@"00123":@"已领取 ¥1.23"};
        for(id amount in examples)timantirecall_check([timantirecall_packetAmountText(amount) isEqual:examples[amount]],@"native fen formats exactly as two-decimal yuan");
        NSArray *invalid=@[@0,@(-1),@YES,@NO,@1.5,@(NAN),@(INFINITY),NSNull.null,@{},@[],@"",@" 1",@"1 ",@"+1",@"-1",@"1.2",@"1e2",@"nan",@"1x",@"１２",@"1000000000000000000"];
        for(id amount in invalid)timantirecall_check(!timantirecall_packetAmountText(amount),@"unknown, zero, non-integer, boolean or malformed amounts do not invent a receipt");
        timantirecall_check(!timantirecall_packetAmountText(nil),@"missing amount produces no message");
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:UIApplication.sharedApplication];
        timantirecall_check(!timantirecall_findPacketToast(),@"amount label from preceding native receipt is cleared on deactivation");
        timantirecall_showPacketAmountText(timantirecall_packetAmountText(@123),timantirecall_window);
        timantirecall_stage(@"packet-amount-ready");timantirecall_stepDelay=0.6;
    });
    timantirecall_step(^{
        UILabel *label=timantirecall_findPacketToast();[timantirecall_window layoutIfNeeded];
        timantirecall_check([label.text isEqual:@"已领取 ¥1.23"],@"amount is visible on the real scene window");
        timantirecall_check(label && fabs(label.center.x-CGRectGetMidX(timantirecall_window.bounds))<1 &&
                           fabs(label.center.y-CGRectGetMidY(timantirecall_window.bounds))<1,@"amount toast is centered in both screen dimensions");
        timantirecall_check(!label.userInteractionEnabled && [timantirecall_window hitTest:label.center withEvent:nil]!=label,@"amount toast does not intercept taps");
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithBounds:timantirecall_window.bounds];
        UIImage *image=[renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context){
            [timantirecall_window drawViewHierarchyInRect:timantirecall_window.bounds afterScreenUpdates:YES];
        }];
        timantirecall_check([UIImagePNGRepresentation(image) writeToFile:timantirecall_document(@"tim-inline-packet-amount-preview.png") atomically:YES],@"centered amount UIKit preview saved");
        timantirecall_stepDelay=2.0;
    });
    timantirecall_step(^{
        timantirecall_check(timantirecall_findPacketToast()!=nil,@"amount remains visible before the three-second deadline");timantirecall_stepDelay=0.7;
    });
    timantirecall_step(^{
        timantirecall_check(!timantirecall_findPacketToast(),@"amount disappears after three seconds without wallet or queue activity");
        timantirecall_showPacketAmountText(timantirecall_packetAmountText(@100),timantirecall_window);timantirecall_stepDelay=1.0;
    });
    timantirecall_step(^{
        timantirecall_showPacketAmountText(timantirecall_packetAmountText(@250),timantirecall_window);timantirecall_stepDelay=2.2;
    });
    timantirecall_step(^{
        NSUInteger count=0;for(UIView *view in timantirecall_window.subviews)
            if([view.accessibilityIdentifier isEqual:@"TIMAntiRecallPacketAmountToast"])count++;
        timantirecall_check(count==1 && [timantirecall_findPacketToast().text isEqual:@"已领取 ¥2.50"],@"new amount replaces rather than stacks; old timer cannot remove it");
        timantirecall_stepDelay=1.05;
    });
    timantirecall_step(^{
        timantirecall_check(!timantirecall_findPacketToast(),@"replacement has its own three-second lifetime");
        timantirecall_showPacketAmountText(timantirecall_packetAmountText(@2),timantirecall_window);
        [NSNotificationCenter.defaultCenter postNotificationName:UISceneWillDeactivateNotification object:[NSObject new]];
        timantirecall_check(timantirecall_findPacketToast()!=nil,@"another scene deactivating does not clear this window's amount");
        if(timantirecall_window.windowScene) {
            [NSNotificationCenter.defaultCenter postNotificationName:UISceneWillDeactivateNotification object:timantirecall_window.windowScene];
            timantirecall_check(!timantirecall_findPacketToast(),@"own scene deactivation clears amount immediately");
        }
        timantirecall_showPacketAmountText(timantirecall_packetAmountText(@3),timantirecall_window);
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:UIApplication.sharedApplication];
        timantirecall_check(!timantirecall_findPacketToast(),@"backgrounding leaves no amount overlay to reappear on return");
        [timantirecall_coverage addObjectsFromArray:@[@"packet-amount-validation",@"packet-amount-center-touch",@"packet-amount-three-seconds",@"packet-amount-refresh",@"packet-amount-lifecycle"]];
    });
}
