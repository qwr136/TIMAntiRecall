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
static Class timantirecall_inlineClass, timantirecall_legacyClass;
static _Atomic(IMP) timantirecall_legacySetOriginal, timantirecall_legacyUpdateOriginal,
    timantirecall_legacyReuseOriginal, timantirecall_legacyLayoutOriginal, timantirecall_legacyWindowOriginal;
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
static BOOL timantirecall_windowActive(UIWindow *window) {
    if(!window || window.hidden || window.alpha<0.01)return NO;
    if(window.windowScene)return window.windowScene.activationState==UISceneActivationStateForegroundActive;
    return UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
}
static id timantirecall_boundModel(UIView *view) {
    if(timantirecall_legacyClass && [view isKindOfClass:timantirecall_legacyClass]) {
        SEL sel=sel_registerName("aioModel");const char *args[]={"@",":"};
        if(!timantirecall_methodTypes(class_getInstanceMethod(object_getClass(view),sel),"@",2,args))return nil;
        return ((id(*)(id,SEL))[view methodForSelector:sel])(view,sel);
    }
    return [TIMAntiRecallRecordBridge timantirecall_currentModelForView:view];
}
static void timantirecall_setupMarks(void);
static void timantirecall_syncRow(UIView *view) {
    if(!NSThread.isMainThread || ![view isKindOfClass:UIView.class])return;
    timantirecall_setupMarks();
    id model=timantirecall_boundModel(view);
    TIMAntiRecallRowContext *context=objc_getAssociatedObject(view,&timantirecall_contextKey);
    if(!model){timantirecall_resetRow(view);return;}
    if(!context || context.timantirecall_model!=model) {
        timantirecall_resetRow(view);
        context=[TIMAntiRecallRowContext new];
        context.timantirecall_view=view;context.timantirecall_model=model;
        context.timantirecall_owner=timantirecall_currentAccount();
        objc_setAssociatedObject(view,&timantirecall_contextKey,context,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [timantirecall_rows addObject:context];
    }
    // A row may bind during startup before currentUid is populated. Resolve an
    // absent owner once; never relabel a known owner when accounts change.
    if(!context.timantirecall_owner.length)context.timantirecall_owner=timantirecall_currentAccount();
    timantirecall_refreshRow(context);
}
static void timantirecall_refreshRow(TIMAntiRecallRowContext *context) {
    if(!context)return;
    UIView *view=context.timantirecall_view;
    if(!view || !timantirecall_hasEvents || !timantirecall_inlineInstalled) {timantirecall_clearVisual(context);return;}
    NSString *owner=timantirecall_currentAccount();
    if(timantirecall_inlinePaused || !view.window ||
       view.hidden || view.alpha<0.01 || !timantirecall_windowActive(view.window) ||
       ![owner isEqual:context.timantirecall_owner]) {timantirecall_clearVisual(context);return;}
    id model=timantirecall_boundModel(view);
    if(!model || model!=context.timantirecall_model) {timantirecall_syncRow(view);return;}
    BOOL legacy=timantirecall_legacyClass && [view isKindOfClass:timantirecall_legacyClass];
    id record=legacy?nil:[TIMAntiRecallRecordBridge timantirecall_recordForViewModel:model];
    NSDictionary *identity=legacy?timantirecall_legacyRowIdentity(model,owner):timantirecall_recordIdentity(record,owner);
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
// One bounded walk per accepted recall batch. It recovers visible rows whose
// Swift binding/layout ran without our Objective-C thunk; never scans text.
static void timantirecall_visitRows(UIView *view,unsigned depth,unsigned *budget) {
    if(!view || depth>24 || !*budget || view.hidden || view.alpha<0.01)return;
    (*budget)--;
    if((timantirecall_inlineClass && [view isKindOfClass:timantirecall_inlineClass]) ||
       (timantirecall_legacyClass && [view isKindOfClass:timantirecall_legacyClass]))
        timantirecall_syncRow(view);
    for(UIView *child in view.subviews) {
        if(!*budget)break;
        timantirecall_visitRows(child,depth+1,budget);
    }
}
static void timantirecall_discoverVisibleRows(void) {
    if(!timantirecall_hasEvents)return;
    unsigned budget=2048;
    NSMutableArray<UIWindow *> *windows=[NSMutableArray array];
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
        if([scene isKindOfClass:UIWindowScene.class])
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
    // TIM 4.1.0.81 has no UIApplicationSceneManifest and may use legacy windows.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [windows addObjectsFromArray:UIApplication.sharedApplication.windows];
#pragma clang diagnostic pop
    for(UIWindow *window in [NSOrderedSet orderedSetWithArray:windows]) {
        if(!budget)break;
        if(timantirecall_windowActive(window))timantirecall_visitRows(window,0,&budget);
    }
}
static void timantirecall_refreshRows(void) {
    timantirecall_discoverVisibleRows();
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
    if(NSThread.isMainThread)timantirecall_syncRow(receiver);
}
static void timantirecall_windowRow(id receiver,SEL selector) {
    IMP original=atomic_load_explicit(&timantirecall_windowOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
    if(NSThread.isMainThread)timantirecall_syncRow(receiver);
}

static Method timantirecall_inlineOwn(Class cls,SEL selector) {
    unsigned count=0;Method result=NULL;Method *methods=class_copyMethodList(cls,&count);
    for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==selector){result=methods[i];break;}
    free(methods);return result;
}
static BOOL timantirecall_installNTRows(void) {
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
static void timantirecall_legacySet(id receiver,SEL selector,id model) {
    if(NSThread.isMainThread)timantirecall_resetRow(receiver);
    IMP original=atomic_load_explicit(&timantirecall_legacySetOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL,id))original)(receiver,selector,model);
    if(NSThread.isMainThread)timantirecall_syncRow(receiver);
}
static void timantirecall_legacyUpdate(id receiver,SEL selector) {
    IMP original=atomic_load_explicit(&timantirecall_legacyUpdateOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
    if(NSThread.isMainThread)timantirecall_syncRow(receiver);
}
static void timantirecall_legacyReuse(id receiver,SEL selector) {
    if(NSThread.isMainThread)timantirecall_resetRow(receiver);
    IMP original=atomic_load_explicit(&timantirecall_legacyReuseOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
}
static void timantirecall_legacyLayout(id receiver,SEL selector) {
    IMP original=atomic_load_explicit(&timantirecall_legacyLayoutOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
    if(NSThread.isMainThread)timantirecall_syncRow(receiver);
}
static void timantirecall_legacyWindow(id receiver,SEL selector) {
    IMP original=atomic_load_explicit(&timantirecall_legacyWindowOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL))original)(receiver,selector);
    if(NSThread.isMainThread)timantirecall_syncRow(receiver);
}
static BOOL timantirecall_installLegacyRows(void) {
    if(timantirecall_legacyClass)return YES;
    if(!timantirecall_installLegacyBridge())return NO;
    Class cls=objc_getClass("QQAIOCell");
    if(!cls || ![cls isSubclassOfClass:UITableViewCell.class])return NO;
    SEL set=sel_registerName("setAioModel:"),update=sel_registerName("updateCellView"),
        reuse=sel_registerName("prepareForReuse"),layout=@selector(layoutSubviews),window=@selector(didMoveToWindow);
    Method sm=timantirecall_inlineOwn(cls,set),um=timantirecall_inlineOwn(cls,update),
        rm=timantirecall_inlineOwn(cls,reuse),lm=timantirecall_inlineOwn(cls,layout),wm=class_getInstanceMethod(cls,window);
    const char *setArgs[]={"@",":","@"};const char *plain[]={"@",":"};
    if(!timantirecall_methodTypes(sm,"v",3,setArgs)||!timantirecall_methodTypes(um,"v",2,plain)||
       !timantirecall_methodTypes(rm,"v",2,plain)||!timantirecall_methodTypes(lm,"v",2,plain)||
       !timantirecall_methodTypes(wm,"v",2,plain)||
       !timantirecall_methodTypes(class_getInstanceMethod(cls,sel_registerName("aioModel")),"@",2,plain))return NO;
    timantirecall_setupMarks();
    atomic_store_explicit(&timantirecall_legacySetOriginal,method_getImplementation(sm),memory_order_release);
    atomic_store_explicit(&timantirecall_legacyUpdateOriginal,method_getImplementation(um),memory_order_release);
    atomic_store_explicit(&timantirecall_legacyReuseOriginal,method_getImplementation(rm),memory_order_release);
    atomic_store_explicit(&timantirecall_legacyLayoutOriginal,method_getImplementation(lm),memory_order_release);
    atomic_store_explicit(&timantirecall_legacyWindowOriginal,method_getImplementation(wm),memory_order_release);
    if(timantirecall_inlineOwn(cls,window))method_setImplementation(wm,(IMP)timantirecall_legacyWindow);
    else if(!class_addMethod(cls,window,(IMP)timantirecall_legacyWindow,method_getTypeEncoding(wm)))return NO;
    method_setImplementation(sm,(IMP)timantirecall_legacySet);
    method_setImplementation(um,(IMP)timantirecall_legacyUpdate);
    method_setImplementation(rm,(IMP)timantirecall_legacyReuse);
    method_setImplementation(lm,(IMP)timantirecall_legacyLayout);
    timantirecall_legacyClass=cls;timantirecall_inlineInstalled=YES;
    timantirecall_bootstrapEvent("inline-legacy-bind-installed");
    return YES;
}
BOOL timantirecall_installInlineIndicator(void) {
    if(!NSThread.isMainThread) {dispatch_async(dispatch_get_main_queue(),^{timantirecall_installInlineIndicator();});return NO;}
    BOOL nt=timantirecall_installNTRows();
    BOOL legacy=timantirecall_installLegacyRows();
    return nt && legacy;
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
