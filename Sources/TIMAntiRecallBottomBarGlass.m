#import "TIMAntiRecallBottomBarGlass.h"
#if defined(TIMANTIRECALL_NATIVE_TEST)
typedef int TIMAntiRecallBottomBarGlassNativeTestTranslationUnit;
#else
#import "TIMAntiRecallMarks.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

static char timantirecall_bottomBarOverlayKey;
static IMP timantirecall_bottomBarOriginalLayout;
static IMP timantirecall_bottomBarOriginalSelect;
static BOOL timantirecall_bottomBarInstalled;

@interface TIMAntiRecallBottomBarGlassOverlay : UIView
@property(nonatomic,strong) UIVisualEffectView *timantirecall_surface;
@property(nonatomic,strong) UIView *timantirecall_surfaceTint;
@property(nonatomic,strong) UIVisualEffectView *timantirecall_lens;
@property(nonatomic,strong) UIView *timantirecall_lensTint;
@property(nonatomic,strong) CAGradientLayer *timantirecall_sheen;
@property(nonatomic) CGRect timantirecall_lastPill;
@property(nonatomic) CGRect timantirecall_lastLens;
- (void)timantirecall_layoutGlass:(CGRect)pill selectedLens:(CGRect)lens animate:(BOOL)animate;
@end

@implementation TIMAntiRecallBottomBarGlassOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];if(!self)return nil;
    self.backgroundColor=UIColor.clearColor;self.userInteractionEnabled=NO;self.accessibilityElementsHidden=YES;
    UIBlurEffect *dark=nil,*light=nil;
    if(@available(iOS 13.0,*)) {
        dark=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        light=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
    } else {dark=[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];light=[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];}
    _timantirecall_surface=[[UIVisualEffectView alloc] initWithEffect:dark];
    _timantirecall_surface.userInteractionEnabled=NO;_timantirecall_surface.clipsToBounds=YES;
    _timantirecall_surface.backgroundColor=UIColor.clearColor;
    _timantirecall_surface.layer.borderWidth=1.1;
    _timantirecall_surface.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.48].CGColor;
    _timantirecall_surface.layer.shadowColor=UIColor.blackColor.CGColor;
    _timantirecall_surface.layer.shadowOpacity=0.28;_timantirecall_surface.layer.shadowRadius=15;
    _timantirecall_surface.layer.shadowOffset=CGSizeMake(0,6);
    [self addSubview:_timantirecall_surface];
    _timantirecall_surfaceTint=[UIView new];_timantirecall_surfaceTint.userInteractionEnabled=NO;
    _timantirecall_surfaceTint.backgroundColor=[UIColor colorWithWhite:0 alpha:0.18];
    [_timantirecall_surface.contentView addSubview:_timantirecall_surfaceTint];
    _timantirecall_lens=[[UIVisualEffectView alloc] initWithEffect:light];
    _timantirecall_lens.userInteractionEnabled=NO;_timantirecall_lens.clipsToBounds=YES;
    _timantirecall_lens.layer.borderWidth=1.2;
    _timantirecall_lens.layer.borderColor=[UIColor colorWithRed:0.80 green:0.94 blue:1 alpha:0.82].CGColor;
    _timantirecall_lens.layer.shadowColor=[UIColor colorWithRed:0.20 green:0.62 blue:1 alpha:1].CGColor;
    _timantirecall_lens.layer.shadowOpacity=0.30;_timantirecall_lens.layer.shadowRadius=9;
    _timantirecall_lens.layer.shadowOffset=CGSizeZero;
    [self addSubview:_timantirecall_lens];
    _timantirecall_lensTint=[UIView new];_timantirecall_lensTint.userInteractionEnabled=NO;
    _timantirecall_lensTint.backgroundColor=[UIColor colorWithRed:0.12 green:0.50 blue:0.94 alpha:0.12];
    [_timantirecall_lens.contentView addSubview:_timantirecall_lensTint];
    _timantirecall_sheen=[CAGradientLayer layer];
    _timantirecall_sheen.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,
        (id)[UIColor colorWithRed:0.76 green:0.93 blue:1 alpha:0.30].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    _timantirecall_sheen.locations=@[@0,@0.5,@1];
    _timantirecall_sheen.startPoint=CGPointMake(0,0.15);_timantirecall_sheen.endPoint=CGPointMake(1,0.85);
    [_timantirecall_lens.contentView.layer addSublayer:_timantirecall_sheen];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timantirecall_reduceMotionChanged:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    return self;
}
- (void)timantirecall_reduceMotionChanged:(NSNotification *)notification {
    (void)notification;
    void (^disableMotion)(void)=^{
        if(![UIAccessibility isReduceMotionEnabled])return;
        [self.layer removeAllAnimations];[self.timantirecall_surface.layer removeAllAnimations];
        [self.timantirecall_lens.layer removeAllAnimations];
        [self.timantirecall_sheen removeAnimationForKey:@"timantirecall_sweep"];
    };
    if(NSThread.isMainThread)disableMotion();else dispatch_async(dispatch_get_main_queue(),disableMotion);
}
- (void)dealloc {[[NSNotificationCenter defaultCenter] removeObserver:self];}
- (void)timantirecall_layoutGlass:(CGRect)pill selectedLens:(CGRect)lens animate:(BOOL)animate {
    BOOL move=CGRectIsEmpty(_timantirecall_lastLens)||!CGRectEqualToRect(lens,_timantirecall_lastLens);
    void (^apply)(void)=^{
        self.timantirecall_surface.frame=pill;
        self.timantirecall_surface.layer.cornerRadius=CGRectGetHeight(pill)*0.5;
        self.timantirecall_surfaceTint.frame=self.timantirecall_surface.contentView.bounds;
        self.timantirecall_lens.frame=lens;
        self.timantirecall_lens.layer.cornerRadius=CGRectGetHeight(lens)*0.5;
        self.timantirecall_lensTint.frame=self.timantirecall_lens.contentView.bounds;
        self.timantirecall_sheen.frame=CGRectMake(-CGRectGetWidth(lens)*0.35,0,CGRectGetWidth(lens)*0.7,CGRectGetHeight(lens));
    };
    if(animate&&move&&self.window&&![UIAccessibility isReduceMotionEnabled])
        [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.16 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut animations:apply completion:nil];
    else apply();
    _timantirecall_lastPill=pill;_timantirecall_lastLens=lens;
    if(move&&![UIAccessibility isReduceMotionEnabled]&&![_timantirecall_sheen animationForKey:@"timantirecall_sweep"]) {
        CABasicAnimation *sweep=[CABasicAnimation animationWithKeyPath:@"position.x"];
        sweep.fromValue=@(-CGRectGetWidth(lens)*0.35);sweep.toValue=@(CGRectGetWidth(lens)*1.35);
        sweep.duration=2.6;sweep.repeatCount=HUGE_VALF;sweep.removedOnCompletion=YES;
        [_timantirecall_sheen addAnimation:sweep forKey:@"timantirecall_sweep"];
    }
}
@end

static IMP timantirecall_bottomBarGetter(id object,const char *name,const char *encoding) {
    if(!object)return NULL;SEL selector=sel_registerName(name);const char *args[]={"@",":"};
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    return timantirecall_methodTypes(method,encoding,2,args)?method_getImplementation(method):NULL;
}
static id timantirecall_bottomBarObjectIvar(id object,const char *name) {
    if(!object)return nil;Ivar ivar=class_getInstanceVariable(object_getClass(object),name);
    const char *type=ivar?ivar_getTypeEncoding(ivar):NULL;
    if(!type||type[0]!='@')return nil;
    return object_getIvar(object,ivar);
}
static UIView *timantirecall_bottomBarDirectChild(UIView *view,UIView *container) {
    UIView *node=view;for(unsigned depth=0;node&&node.superview&&node.superview!=container&&depth<24;depth++)node=node.superview;
    return node&&node.superview==container?node:nil;
}
static NSArray<NSDictionary *> *timantirecall_bottomBarItems(UIView *bar) {
    Class rootClass=objc_getClass("QQToolBarRootView");if(!rootClass||![bar isKindOfClass:UIView.class])return nil;
    IMP getter=timantirecall_bottomBarGetter(bar,"barItemDic","@");if(!getter)return nil;
    id dictionary=((id(*)(id,SEL))getter)(bar,sel_registerName("barItemDic"));
    if(![dictionary isKindOfClass:NSDictionary.class]||dictionary.count<2||dictionary.count>8)return nil;
    NSMutableArray *items=[NSMutableArray array];NSMutableSet *indexes=[NSMutableSet set];
    for(id candidate in [dictionary allValues]) {
        if(![candidate isKindOfClass:rootClass]||![candidate isKindOfClass:UIView.class])return nil;
        IMP indexGetter=timantirecall_bottomBarGetter(candidate,"iShowingIndex","q");if(!indexGetter)return nil;
        int64_t index=((int64_t(*)(id,SEL))indexGetter)(candidate,sel_registerName("iShowingIndex"));
        if(index<0||index>7||[indexes containsObject:@(index)])return nil;
        UIView *direct=timantirecall_bottomBarDirectChild(candidate,bar);if(!direct)return nil;
        CGRect frame=[candidate convertRect:candidate.bounds toView:bar];
        if(CGRectIsEmpty(frame)||CGRectIsInfinite(frame)||!isfinite(frame.origin.x)||!isfinite(frame.origin.y)||!isfinite(frame.size.width)||!isfinite(frame.size.height))return nil;
        [indexes addObject:@(index)];[items addObject:@{@"root":candidate,@"direct":direct,@"index":@(index),@"frame":[NSValue valueWithCGRect:frame]}];
    }
    return items.count==dictionary.count?items.copy:nil;
}
static UIViewController *timantirecall_bottomBarRootController(void) {
    Class cls=objc_getClass("QQTabBarController");if(!cls||![cls isSubclassOfClass:UIViewController.class])return nil;
    SEL selector=sel_registerName("appQQTabBarController");const char *args[]={"@",":"};
    Method method=class_getClassMethod(cls,selector);
    if(!timantirecall_methodTypes(method,"@",2,args))return nil;
    id controller=((id(*)(id,SEL))method_getImplementation(method))(cls,selector);
    return [controller isKindOfClass:cls]?(UIViewController *)controller:nil;
}
static UIView *timantirecall_bottomBarRootView(UIViewController *controller) {
    SEL selector=sel_registerName("tabBarView");const char *args[]={"@",":"};
    Method method=controller?class_getInstanceMethod(object_getClass(controller),selector):NULL;
    if(!timantirecall_methodTypes(method,"@",2,args))return nil;
    id view=((id(*)(id,SEL))method_getImplementation(method))(controller,selector);
    return [view isKindOfClass:UIView.class]?(UIView *)view:nil;
}
static BOOL timantirecall_bottomBarSelectedIndex(UIViewController *controller,uint64_t *index) {
    SEL selector=sel_registerName("tabBarIndex");const char *args[]={"@",":"};
    Method method=controller?class_getInstanceMethod(object_getClass(controller),selector):NULL;
    if(!timantirecall_methodTypes(method,"Q",2,args))return NO;
    uint64_t value=((uint64_t(*)(id,SEL))method_getImplementation(method))(controller,selector);
    if(index)*index=value;return YES;
}
static NSUInteger timantirecall_bottomBarBackgroundIndex(UIView *bar,BOOL *found) {
    BOOL any=NO;NSUInteger maxIndex=0;
    const char *names[]={"_bgImageView","_bgImageEffectView","_effectMaskView","_blurEffectView","_line"};
    for(unsigned n=0;n<sizeof(names)/sizeof(names[0]);n++) {
        id view=timantirecall_bottomBarObjectIvar(bar,names[n]);
        if(![view isKindOfClass:UIView.class]||[(UIView *)view superview]!=bar)continue;
        NSUInteger index=[bar.subviews indexOfObjectIdenticalTo:view];
        if(index!=NSNotFound){maxIndex=any?MAX(maxIndex,index):index;any=YES;}
    }
    if(found)*found=any;return any?maxIndex:0;
}
static void timantirecall_bottomBarApply(id object,BOOL overrideSelected,uint64_t selectedOverride,BOOL animate) {
    if(!NSThread.isMainThread||![object isKindOfClass:UIView.class])return;
    Class barClass=objc_getClass("QQSkinTabBar");UIView *bar=(UIView *)object;
    if(!barClass||object_getClass(bar)!=barClass||!bar.window||bar.hidden||bar.alpha<0.01)return;
    UIViewController *controller=timantirecall_bottomBarRootController();
    if(!controller||timantirecall_bottomBarRootView(controller)!=bar)return;
    uint64_t selected=0;if(overrideSelected)selected=selectedOverride;else if(!timantirecall_bottomBarSelectedIndex(controller,&selected))return;
    NSArray<NSDictionary *> *items=timantirecall_bottomBarItems(bar);if(!items||items.count<2||selected>=8)return;
    NSDictionary *selectedItem=nil;NSMutableArray<UIView *> *directItems=[NSMutableArray array];
    for(NSDictionary *item in items) {
        if([item[@"index"] unsignedLongLongValue]==selected)selectedItem=item;
        UIView *direct=item[@"direct"];if(![directItems containsObject:direct])[directItems addObject:direct];
    }
    if(!selectedItem)return;
    CGRect bounds=bar.bounds;if(CGRectIsEmpty(bounds)||bounds.size.width<120||bounds.size.height<36)return;
    TIMAntiRecallBottomBarGlassOverlay *overlay=objc_getAssociatedObject(bar,&timantirecall_bottomBarOverlayKey);
    if(!overlay) {
        overlay=[[TIMAntiRecallBottomBarGlassOverlay alloc] initWithFrame:bounds];
        BOOL hasBackground=NO;NSUInteger index=timantirecall_bottomBarBackgroundIndex(bar,&hasBackground);
        NSUInteger insertion=hasBackground?MIN(index+1,bar.subviews.count):0;
        [bar insertSubview:overlay atIndex:insertion];
        objc_setAssociatedObject(bar,&timantirecall_bottomBarOverlayKey,overlay,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    overlay.frame=bounds;
    BOOL hasBackground=NO;NSUInteger bgIndex=timantirecall_bottomBarBackgroundIndex(bar,&hasBackground);
    NSUInteger overlayIndex=[bar.subviews indexOfObjectIdenticalTo:overlay];
    if(hasBackground&&overlayIndex!=NSNotFound&&overlayIndex<=bgIndex)
        [bar insertSubview:overlay atIndex:MIN(bgIndex+1,bar.subviews.count)];
    for(UIView *direct in directItems)if(direct.superview==bar)[bar bringSubviewToFront:direct];
    id pluginView=timantirecall_bottomBarObjectIvar(bar,"_pluginTagView");
    UIView *pluginDirect=[pluginView isKindOfClass:UIView.class]?timantirecall_bottomBarDirectChild(pluginView,bar):nil;
    if(pluginDirect)[bar bringSubviewToFront:pluginDirect];
    overlay.frame=bar.bounds;
    CGFloat safeBottom=MAX(0,bar.safeAreaInsets.bottom);
    CGFloat contentHeight=CGRectGetHeight(bounds)-MIN(safeBottom,CGRectGetHeight(bounds)*0.45);
    if(contentHeight<40)contentHeight=CGRectGetHeight(bounds);
    CGFloat pillHeight=MIN(62,contentHeight-6);
    if(pillHeight<40)return;
    CGFloat pillWidth=CGRectGetWidth(bounds)-28;
    CGRect pill=CGRectMake(14,MAX(3,(contentHeight-pillHeight)*0.5),pillWidth,pillHeight);
    CGRect itemFrame=[selectedItem[@"frame"] CGRectValue];
    CGFloat centerX=CGRectGetMidX(itemFrame);
    CGFloat edgeRoom=2.0*MIN(centerX-CGRectGetMinX(pill),CGRectGetMaxX(pill)-centerX);
    CGFloat requestedWidth=MAX(68,itemFrame.size.width+14);
    CGFloat lensWidth=MIN(requestedWidth,edgeRoom);
    if(!isfinite(centerX)||!isfinite(lensWidth)||lensWidth<44)return;
    CGRect lens=CGRectMake(centerX-lensWidth*0.5,CGRectGetMinY(pill)+3,lensWidth,CGRectGetHeight(pill)-6);
    [overlay timantirecall_layoutGlass:pill selectedLens:lens animate:animate];
}
static Method timantirecall_bottomBarOwnMethod(Class cls,SEL selector) {
    unsigned count=0;Method *methods=class_copyMethodList(cls,&count);Method result=NULL;
    for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==selector){result=methods[i];break;}
    free(methods);return result;
}
static void timantirecall_bottomBarLayout(id bar,SEL selector) {
    IMP original=timantirecall_bottomBarOriginalLayout;if(original)((void(*)(id,SEL))original)(bar,selector);
    timantirecall_bottomBarApply(bar,NO,0,NO);
}
static void timantirecall_bottomBarSelected(id bar,SEL selector,uint64_t index) {
    IMP original=timantirecall_bottomBarOriginalSelect;if(original)((void(*)(id,SEL,uint64_t))original)(bar,selector,index);
    if(NSThread.isMainThread)timantirecall_bottomBarApply(bar,YES,index,YES);
    else dispatch_async(dispatch_get_main_queue(),^{timantirecall_bottomBarApply(bar,YES,index,YES);});
}
BOOL timantirecall_installBottomBarGlass(void) {
    if(!NSThread.isMainThread)return NO;
    if(timantirecall_bottomBarInstalled)return YES;
    Class cls=objc_getClass("QQSkinTabBar");if(!cls||![cls isSubclassOfClass:UIView.class])return NO;
    SEL layoutSelector=@selector(layoutSubviews),selectSelector=sel_registerName("setTabBarSelectedAtIndex:");
    const char *layoutArgs[]={"@",":"};const char *selectArgs[]={"@",":","Q"};
    Method layout=timantirecall_bottomBarOwnMethod(cls,layoutSelector);
    Method select=timantirecall_bottomBarOwnMethod(cls,selectSelector);
    if(!timantirecall_methodTypes(layout,"v",2,layoutArgs)||!timantirecall_methodTypes(select,"v",3,selectArgs))return NO;
    IMP originalLayout=method_getImplementation(layout),originalSelect=method_getImplementation(select);
    if(!originalLayout||!originalSelect||(IMP)timantirecall_bottomBarLayout==originalLayout||(IMP)timantirecall_bottomBarSelected==originalSelect)return NO;
    timantirecall_bottomBarOriginalLayout=originalLayout;timantirecall_bottomBarOriginalSelect=originalSelect;
    method_setImplementation(layout,(IMP)timantirecall_bottomBarLayout);
    method_setImplementation(select,(IMP)timantirecall_bottomBarSelected);
    timantirecall_bottomBarInstalled=YES;return YES;
}
#ifdef TIMANTIRECALL_UI_TEST
BOOL timantirecall_testBottomBarGlass(UIView *bar) {
    TIMAntiRecallBottomBarGlassOverlay *overlay=objc_getAssociatedObject(bar,&timantirecall_bottomBarOverlayKey);
    if(!overlay||overlay.superview!=bar||overlay.userInteractionEnabled)return NO;
    if(!overlay.timantirecall_surface||!overlay.timantirecall_lens||CGRectIsEmpty(overlay.timantirecall_lastPill)||CGRectIsEmpty(overlay.timantirecall_lastLens))return NO;
    return overlay.timantirecall_surface.frame.size.height>=40&&overlay.timantirecall_lens.alpha>0.01;
}
CGRect timantirecall_testBottomBarGlassLensFrame(UIView *bar) {
    TIMAntiRecallBottomBarGlassOverlay *overlay=objc_getAssociatedObject(bar,&timantirecall_bottomBarOverlayKey);
    return overlay?overlay.timantirecall_lastLens:CGRectZero;
}
#endif
#endif
