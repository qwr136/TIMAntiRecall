#import "TIMAntiRecallPacketToast.h"
#import <CoreFoundation/CoreFoundation.h>

NSString *timantirecall_packetAmountText(id minorUnits) {
    NSString *digits=nil;
    if([minorUnits isKindOfClass:NSNumber.class]) {
        if(CFGetTypeID((__bridge CFTypeRef)minorUnits)==CFBooleanGetTypeID())return nil;
        digits=[minorUnits stringValue];
    } else if([minorUnits isKindOfClass:NSString.class])digits=minorUnits;
    if(!digits.length || digits.length>18)return nil;
    unsigned long long fen=0;
    for(NSUInteger i=0;i<digits.length;i++) {
        unichar c=[digits characterAtIndex:i];
        if(c<'0' || c>'9')return nil;
        fen=fen*10+(c-'0');
    }
    if(!fen)return nil;
    return [NSString stringWithFormat:@"已领取 ¥%llu.%02llu",fen/100,fen%100];
}

#ifdef TIMANTIRECALL_NATIVE_TEST
void timantirecall_showPacketAmountText(NSString *text,UIWindow *window) {(void)text;(void)window;}
#else
#import <UIKit/UIKit.h>
#include <math.h>

static UILabel *timantirecall_packetToast;
static __weak UIWindow *timantirecall_packetToastWindow;
static NSUInteger timantirecall_packetToastGeneration;
static NSArray *timantirecall_packetToastObservers;
static void timantirecall_clearPacketToast(void) {
    timantirecall_packetToastGeneration++;
    [timantirecall_packetToast removeFromSuperview];
    timantirecall_packetToast=nil;timantirecall_packetToastWindow=nil;
}
static void timantirecall_packetToastLifecycle(NSNotification *note) {
    BOOL sceneEvent=[note.name isEqual:UISceneWillDeactivateNotification] || [note.name isEqual:UISceneDidDisconnectNotification];
    if(sceneEvent && note.object!=timantirecall_packetToastWindow.windowScene)return;
    timantirecall_clearPacketToast();
}
static void timantirecall_installPacketToastObservers(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSMutableArray *observers=[NSMutableArray array];
        for(NSString *name in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,
                               UISceneWillDeactivateNotification,UISceneDidDisconnectNotification]) {
            id token=[NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note){timantirecall_packetToastLifecycle(note);}];
            [observers addObject:token];
        }
        timantirecall_packetToastObservers=[observers copy];
    });
}
void timantirecall_showPacketAmountText(NSString *text,UIWindow *window) {
    if(!NSThread.isMainThread || ![text isKindOfClass:NSString.class] || !text.length || text.length>80 ||
       UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || !window || window.hidden ||
       window.alpha<=0.01 || window.windowLevel!=UIWindowLevelNormal ||
       (window.windowScene && window.windowScene.activationState!=UISceneActivationStateForegroundActive))return;
    timantirecall_installPacketToastObservers();
    // New receipts replace the visible amount and restart only this UI timer.
    // No wallet callback, view-controller transition or claim queue is awaited.
    timantirecall_clearPacketToast();
    NSUInteger generation=timantirecall_packetToastGeneration;
    UILabel *label=[UILabel new];
    label.text=text;label.textAlignment=NSTextAlignmentCenter;label.numberOfLines=1;
    label.textColor=UIColor.whiteColor;label.backgroundColor=[UIColor colorWithWhite:0.0 alpha:0.82];
    label.font=[UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    label.adjustsFontSizeToFitWidth=YES;label.minimumScaleFactor=0.6;
    label.layer.cornerRadius=12.0;label.layer.masksToBounds=YES;
    label.userInteractionEnabled=NO;label.accessibilityIdentifier=@"TIMAntiRecallPacketAmountToast";
    timantirecall_packetToast=label;timantirecall_packetToastWindow=window;
    [window addSubview:label];label.translatesAutoresizingMaskIntoConstraints=NO;
    CGFloat width=MAX(196.0,ceil([label sizeThatFits:CGSizeMake(CGFLOAT_MAX,60.0)].width)+40.0);
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:window.centerYAnchor],
        [label.heightAnchor constraintEqualToConstant:60.0],
        [label.widthAnchor constraintEqualToConstant:MIN(width,MAX(1.0,CGRectGetWidth(window.bounds)-48.0))]
    ]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(generation==timantirecall_packetToastGeneration)timantirecall_clearPacketToast();
    });
}
#endif
