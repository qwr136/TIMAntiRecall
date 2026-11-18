#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallBootstrap.h"
#import "TIMAntiRecallIndicatorView.h"
#import "TIMAntiRecall-Swift.h"
#import <objc/runtime.h>
#include <stdatomic.h>
#include <math.h>
#include <stdlib.h>

@interface TIMAntiRecallRowContext : NSObject
@property(nonatomic,weak) UIView *timantirecall_view;
@property(nonatomic,weak) id timantirecall_model;
@property(nonatomic,copy) NSString *timantirecall_owner;
@property(nonatomic,strong) TIMAntiRecallIndicatorView *timantirecall_indicator;
@end
@implementation TIMAntiRecallRowContext
- (void)dealloc {
    TIMAntiRecallIndicatorView *indicator=_timantirecall_indicator;
    if(NSThread.isMainThread)[indicator removeFromSuperview];
    else if(indicator)dispatch_async(dispatch_get_main_queue(),^{[indicator removeFromSuperview];});
}
@end

static char timantirecall_contextKey;
static TIMAntiRecallMarkStore *timantirecall_marks;
static NSHashTable<TIMAntiRecallRowContext *> *timantirecall_rows;
static Class timantirecall_inlineClass;
static _Atomic(IMP) timantirecall_bindOriginal, timantirecall_unbindOriginal,
    timantirecall_reuseOriginal, timantirecall_layoutOriginal, timantirecall_windowOriginal;
static BOOL timantirecall_inlinePaused;
static BOOL timantirecall_hasEvents;
static BOOL timantirecall_inlineInstalled;
static void timantirecall_refreshRow(TIMAntiRecallRowContext *context);

static void timantirecall_clearVisual(TIMAntiRecallRowContext *context) {
    [context.timantirecall_indicator removeFromSuperview];context.timantirecall_indicator=nil;
}
static void timantirecall_resetRow(UIView *view) {
    TIMAntiRecallRowContext *context=objc_getAssociatedObject(view,&timantirecall_contextKey);
    timantirecall_clearVisual(context);
    if(context)[timantirecall_rows removeObject:context];
    objc_setAssociatedObject(view,&timantirecall_contextKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static UIView *timantirecall_rowHost(UIView *view) {
    UIView *cursor=view;
    for(unsigned depth=0;cursor && depth<12;depth++,cursor=cursor.superview) {
        if([cursor isKindOfClass:UITableViewCell.class])return ((UITableViewCell *)cursor).contentView;
        if([cursor isKindOfClass:UICollectionViewCell.class])return ((UICollectionViewCell *)cursor).contentView;
    }
    return view;
}
static void timantirecall_refreshRow(TIMAntiRecallRowContext *context) {
    if(!context)return;
    UIView *view=context.timantirecall_view;
    if(!view || !timantirecall_hasEvents || !timantirecall_inlineInstalled) {timantirecall_clearVisual(context);return;}
    NSString *owner=timantirecall_currentAccount();
    if(timantirecall_inlinePaused || !view.window ||
       view.hidden || view.alpha<0.01 || view.window.windowScene.activationState!=UISceneActivationStateForegroundActive ||
       ![owner isEqual:context.timantirecall_owner]) {timantirecall_clearVisual(context);return;}
    id model=context.timantirecall_model;
    id record=model?[TIMAntiRecallRecordBridge timantirecall_recordForViewModel:model]:nil;
    NSDictionary *identity=timantirecall_recordIdentity(record,owner);
    if(![timantirecall_marks timantirecall_containsIdentity:identity]) {timantirecall_clearVisual(context);return;}
    UIView *host=timantirecall_rowHost(view);
    CGRect bounds=host.bounds;
    if(host.window!=view.window || bounds.size.width<120 || bounds.size.height<32 ||
       !isfinite(bounds.size.width) || !isfinite(bounds.size.height)) {timantirecall_clearVisual(context);return;}
    if(!context.timantirecall_indicator) {
        context.timantirecall_indicator=[[TIMAntiRecallIndicatorView alloc] initWithFrame:CGRectZero];
        static unsigned matched=0;if(matched++<8)timantirecall_bootstrapEvent("inline-exact-account-peer-seq-match");
    }
    if(context.timantirecall_indicator.superview!=host) {
        [context.timantirecall_indicator removeFromSuperview];[host addSubview:context.timantirecall_indicator];
    }
    [context.timantirecall_indicator timantirecall_fitToBounds:bounds];
    [host bringSubviewToFront:context.timantirecall_indicator];
}
static void timantirecall_refreshRows(void) {
    for(TIMAntiRecallRowContext *context in timantirecall_rows.allObjects)timantirecall_refreshRow(context);
}
static void timantirecall_setupMarks(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        timantirecall_marks=[TIMAntiRecallMarkStore new];
        timantirecall_rows=[NSHashTable weakObjectsHashTable];
        NSMutableArray *tokens=[NSMutableArray array];
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        for(NSNotificationName name in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification]) {
            id token=[center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){
                timantirecall_inlinePaused=YES;
                for(TIMAntiRecallRowContext *row in timantirecall_rows.allObjects)timantirecall_clearVisual(row);
            }];[tokens addObject:token];
        }
        [tokens addObject:[center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){
            timantirecall_inlinePaused=NO;timantirecall_refreshRows();
        }]];
        [tokens addObject:[center addObserverForName:UISceneWillDeactivateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            for(TIMAntiRecallRowContext *row in timantirecall_rows.allObjects)
                if(row.timantirecall_view.window.windowScene==note.object)timantirecall_clearVisual(row);
        }]];
        [tokens addObject:[center addObserverForName:UISceneDidActivateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){
            timantirecall_refreshRows();
        }]];
        static NSArray *timantirecall_observers;timantirecall_observers=[tokens copy];
        (void)timantirecall_observers;
    });
}
static BOOL timantirecall_bindRow(id receiver,SEL selector,id model) {
    BOOL main=NSThread.isMainThread;
    if(main)timantirecall_resetRow(receiver);
    IMP original=atomic_load_explicit(&timantirecall_bindOriginal,memory_order_acquire);
    BOOL result=original?((BOOL(*)(id,SEL,id))original)(receiver,selector,model):NO;
    if(main && result && [receiver isKindOfClass:UIView.class]) {
        timantirecall_setupMarks();
        TIMAntiRecallRowContext *context=[TIMAntiRecallRowContext new];
        context.timantirecall_view=receiver;context.timantirecall_model=model;
        context.timantirecall_owner=timantirecall_currentAccount();
        objc_setAssociatedObject(receiver,&timantirecall_contextKey,context,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [timantirecall_rows addObject:context];timantirecall_refreshRow(context);
    }
    return result;
}
static void timantirecall_unbindRow(id receiver,SEL selector) {
    if(NSThread.isMainThread)timantirecall_resetRow(receiver);
    IMP original=atomic_load_explicit(&timantirecall_unbindOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
}
static void timantirecall_reuseRow(id receiver,SEL selector) {
    if(NSThread.isMainThread)timantirecall_resetRow(receiver);
    IMP original=atomic_load_explicit(&timantirecall_reuseOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
}
static void timantirecall_layoutRow(id receiver,SEL selector) {
    IMP original=atomic_load_explicit(&timantirecall_layoutOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
    if(NSThread.isMainThread)timantirecall_refreshRow(objc_getAssociatedObject(receiver,&timantirecall_contextKey));
}
static void timantirecall_windowRow(id receiver,SEL selector) {
    IMP original=atomic_load_explicit(&timantirecall_windowOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
    if(NSThread.isMainThread)timantirecall_refreshRow(objc_getAssociatedObject(receiver,&timantirecall_contextKey));
}

static Method timantirecall_inlineOwn(Class cls,SEL selector) {
    unsigned count=0;Method result=NULL;Method *methods=class_copyMethodList(cls,&count);
    for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==selector){result=methods[i];break;}
    free(methods);return result;
}
BOOL timantirecall_installInlineIndicator(void) {
    if(!NSThread.isMainThread) {dispatch_async(dispatch_get_main_queue(),^{timantirecall_installInlineIndicator();});return NO;}
    if(timantirecall_inlineClass)return YES;
#ifdef TIMANTIRECALL_UI_TEST
    Class cls=objc_getClass("TIMAntiRecallTestBaseView");
#else
    Class cls=objc_getClass("_TtC13NTAIOBaseCell17NTAIOBaseCellView");
#endif
    if(!cls || ![cls isSubclassOfClass:UIView.class])return NO;
    SEL bind=sel_registerName("bindViewModel:"),unbind=sel_registerName("unbindViewModel"),reuse=sel_registerName("prepareForReuse"),layout=@selector(layoutSubviews),window=@selector(didMoveToWindow);
    Method bm=timantirecall_inlineOwn(cls,bind),um=timantirecall_inlineOwn(cls,unbind),rm=timantirecall_inlineOwn(cls,reuse),lm=timantirecall_inlineOwn(cls,layout);
    Method wm=class_getInstanceMethod(cls,window);
    const char *bindArgs[]={"@",":","@"};const char *plainArgs[]={"@",":"};
    if(!timantirecall_methodTypes(bm,"B",3,bindArgs)||!timantirecall_methodTypes(um,"v",2,plainArgs)||
       !timantirecall_methodTypes(rm,"v",2,plainArgs)||!timantirecall_methodTypes(lm,"v",2,plainArgs)||
       !timantirecall_methodTypes(wm,"v",2,plainArgs))return NO;
    timantirecall_setupMarks();
    atomic_store_explicit(&timantirecall_bindOriginal,method_getImplementation(bm),memory_order_release);
    atomic_store_explicit(&timantirecall_unbindOriginal,method_getImplementation(um),memory_order_release);
    atomic_store_explicit(&timantirecall_reuseOriginal,method_getImplementation(rm),memory_order_release);
    atomic_store_explicit(&timantirecall_layoutOriginal,method_getImplementation(lm),memory_order_release);
    atomic_store_explicit(&timantirecall_windowOriginal,method_getImplementation(wm),memory_order_release);
    // Materialize an inherited UIKit override on this class, never mutate UIView.
    if(timantirecall_inlineOwn(cls,window)) method_setImplementation(wm,(IMP)timantirecall_windowRow);
    else if(!class_addMethod(cls,window,(IMP)timantirecall_windowRow,method_getTypeEncoding(wm)))return NO;
    method_setImplementation(bm,(IMP)timantirecall_bindRow);
    method_setImplementation(um,(IMP)timantirecall_unbindRow);
    method_setImplementation(rm,(IMP)timantirecall_reuseRow);
    method_setImplementation(lm,(IMP)timantirecall_layoutRow);
    timantirecall_inlineClass=cls;
    timantirecall_inlineInstalled=YES;
    timantirecall_bootstrapEvent("inline-nt-bind-installed");
    return YES;
}
void timantirecall_markIntercepted(NSData *data,NSString *owner) {
    NSArray *events=timantirecall_recallEvents(data);
    if(!events.count || !owner.length)return;
    NSString *account=[owner copy];
    dispatch_async(dispatch_get_main_queue(),^{
        timantirecall_installInlineIndicator();
        timantirecall_setupMarks();
        if(![timantirecall_currentAccount() isEqual:account])return;
        [timantirecall_marks timantirecall_addEvents:events owner:account];
        timantirecall_hasEvents=YES;
        timantirecall_refreshRows();
    });
}
