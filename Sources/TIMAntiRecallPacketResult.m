#import "TIMAntiRecallPacketResult.h"
#ifdef TIMANTIRECALL_NATIVE_TEST
@implementation TIMAntiRecallPacketResult
- (instancetype)initWithPresenter:(id)presenter walletService:(Class)service bill:(NSString *)bill {(void)presenter;(void)service;(void)bill;return [super init];}
- (BOOL)timantirecall_refresh {return NO;}
- (BOOL)timantirecall_returnToOrigin {return NO;}
- (BOOL)timantirecall_originRestored {return NO;}
- (BOOL)timantirecall_hasOwnedPage {return NO;}
@end
#else
#import "TIMAntiRecallPacketReceipt.h"
#import "TIMAntiRecallMarks.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
@interface TIMAntiRecallPacketResult ()
@property(nonatomic,weak) UIViewController *timantirecall_presenter, *timantirecall_result;
@property(nonatomic,weak) UIWindow *timantirecall_window;
@property(nonatomic,strong) NSHashTable<UIViewController *> *timantirecall_before;
@property(nonatomic,copy) NSString *timantirecall_bill;
@property(nonatomic) BOOL timantirecall_returning;
@end
static BOOL timantirecall_resultVisible(UIView *view,UIWindow *window) {
    if(!window || !view || view.window!=window || CGRectIsEmpty(view.bounds))return NO;
    for(UIView *parent=view;parent;parent=parent.superview)if(parent.hidden || parent.alpha<0.05)return NO;
    return CGRectIntersectsRect(window.bounds,[view convertRect:view.bounds toView:window]);
}
static NSArray<UIViewController *> *timantirecall_resultControllers(UIWindow *window) {
    if(!window)return @[];
    NSMutableArray<UIView *> *views=[NSMutableArray arrayWithObject:window];
    NSHashTable<UIViewController *> *controllers=[NSHashTable weakObjectsHashTable];
    for(NSUInteger i=0;i<views.count;i++) {
        UIView *view=views[i];if(views.count+view.subviews.count>1024)return nil;
        [views addObjectsFromArray:view.subviews];UIResponder *responder=view.nextResponder;
        for(NSUInteger depth=0;responder && depth<24;depth++,responder=responder.nextResponder)
            if([responder isKindOfClass:UIViewController.class]){[controllers addObject:(UIViewController *)responder];break;}
    }
    return controllers.allObjects;
}
static id timantirecall_resultObject(id object,const char *name) {
    if(!object || !timantirecall_walletTrustedClass(object_getClass(object)))return nil;
    SEL getter=sel_registerName(name);Method method=class_getInstanceMethod(object_getClass(object),getter);
    const char *args[]={"@",":"};if(!timantirecall_methodTypes(method,"@",2,args))return nil;
    return ((id(*)(id,SEL))method_getImplementation(method))(object,getter);
}
@implementation TIMAntiRecallPacketResult
- (instancetype)initWithPresenter:(id)presenter walletService:(Class)service bill:(NSString *)bill {
    if((self=[super init])) {
        if(![presenter isKindOfClass:UIViewController.class])return nil;
        (void)service;self.timantirecall_presenter=presenter;self.timantirecall_window=((UIViewController *)presenter).viewIfLoaded.window;
        self.timantirecall_bill=[bill isKindOfClass:NSString.class]?[bill copy]:nil;
        self.timantirecall_before=[NSHashTable weakObjectsHashTable];
        NSArray *before=timantirecall_resultControllers(self.timantirecall_window);if(!before)return nil;
        for(UIViewController *controller in before)[self.timantirecall_before addObject:controller];
    }
    return self;
}
- (UIViewController *)timantirecall_candidate {
    UIWindow *window=self.timantirecall_window;
    if(!window.isKeyWindow || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || !self.timantirecall_bill.length)return nil;
    Class detail=objc_getClass("CFT_UIRedGiftDetailBaseViewController");UIViewController *match=nil;
    if(!detail || !timantirecall_walletTrustedClass(detail))return nil;
    NSArray *controllers=timantirecall_resultControllers(window);if(!controllers)return nil;
    for(UIViewController *controller in controllers) {
        if(![controller isKindOfClass:detail] || [self.timantirecall_before containsObject:controller] ||
           !timantirecall_resultVisible(controller.viewIfLoaded,window) || controller.isBeingDismissed || controller.transitionCoordinator)continue;
        id bill=timantirecall_resultObject(controller,"listid");
        if(![bill isKindOfClass:NSString.class] || ![bill isEqual:self.timantirecall_bill])continue;
        if(match)return nil;match=controller;
    }
    return match;
}
- (BOOL)timantirecall_refresh {
    UIViewController *candidate=[self timantirecall_candidate];
    if(candidate && candidate!=self.timantirecall_result && self.timantirecall_log)
        self.timantirecall_log(@"result-controller",class_getName(object_getClass(candidate)));
    if(candidate)self.timantirecall_result=candidate;
    return candidate!=nil;
}
- (BOOL)timantirecall_returnToOrigin {
    UIViewController *result=[self timantirecall_candidate];
    if(!result || result!=self.timantirecall_result || self.timantirecall_returning)return NO;
    id navigation=timantirecall_resultObject(result,"customNavigationView");
    Class navigationClass=objc_getClass("CFT_UIRedGiftCustomNavigationView");
    if(!navigationClass || ![navigation isKindOfClass:navigationClass])return NO;
    id button=timantirecall_resultObject(navigation,"leftButton");
    if(![button isKindOfClass:UIControl.class] || !((UIControl *)button).enabled ||
       !timantirecall_resultVisible(button,self.timantirecall_window))return NO;
    UIControl *control=button;NSUInteger count=0;id target=nil;NSString *action=nil;
    for(id receiver in control.allTargets)for(NSString *name in [control actionsForTarget:receiver forControlEvent:UIControlEventTouchUpInside]) {
        count++;target=receiver;action=name;
    }
    const char *args[]={"@",":","@"};
    Method method=class_getInstanceMethod(object_getClass(navigation),sel_registerName("leftButtonClick:"));
    if(count!=1 || target!=navigation || ![action isEqual:@"leftButtonClick:"] || !timantirecall_methodTypes(method,"v",3,args))return NO;
    CGPoint point=[control convertPoint:CGPointMake(CGRectGetMidX(control.bounds),CGRectGetMidY(control.bounds)) toView:self.timantirecall_window];
    UIView *hit=[self.timantirecall_window hitTest:point withEvent:nil];
    if(!hit || (hit!=control && ![hit isDescendantOfView:control]))return NO;
    self.timantirecall_returning=YES;
    [control sendActionsForControlEvents:UIControlEventTouchUpInside];return YES;
}
- (BOOL)timantirecall_originRestored {
    UIViewController *presenter=self.timantirecall_presenter;
    return presenter && !presenter.presentedViewController && !presenter.transitionCoordinator &&
        timantirecall_resultVisible(presenter.viewIfLoaded,self.timantirecall_window) && ![self timantirecall_hasOwnedPage];
}
- (BOOL)timantirecall_hasOwnedPage {
    UIViewController *result=self.timantirecall_result;
    return self.timantirecall_window && result && result.viewIfLoaded.window==self.timantirecall_window;
}
@end
#endif
