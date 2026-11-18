#import "TIMAntiRecallToast.h"
#import <UIKit/UIKit.h>
#import <stdatomic.h>

static atomic_uint timantirecall_toastRequests = 0;
static atomic_flag timantirecall_toastVisible = ATOMIC_FLAG_INIT;
static UIView *timantirecall_toastView;
static NSUInteger timantirecall_toastGeneration = 0;
static id timantirecall_lifecycleObserver;

static UIWindow *timantirecall_foregroundWindow(void) {
    UIApplication *application = UIApplication.sharedApplication;
    UIWindow *best=nil; NSInteger bestScore=NSIntegerMin;
    for (UIScene *scene in application.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:UIWindowScene.class]) continue;
        NSInteger sceneScore = 2;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha <= 0.01 || window.windowLevel != UIWindowLevelNormal) continue;
            UIViewController *controller = window.rootViewController;
            if (!controller || controller.view.hidden || controller.view.alpha <= 0.01) continue;
            NSInteger score=sceneScore+(window.isKeyWindow?2:0);
            if (score>bestScore) { best=window; bestScore=score; }
        }
    }
    return best;
}

static void timantirecall_lifecycleChanged(NSNotification *note) {
    if ([note.name isEqualToString:UISceneWillDeactivateNotification] ||
        [note.name isEqualToString:UIApplicationWillResignActiveNotification] ||
        [note.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
        timantirecall_toastGeneration += 1;
        [timantirecall_toastView removeFromSuperview];
        timantirecall_toastView = nil;
        atomic_flag_clear_explicit(&timantirecall_toastVisible, memory_order_release);
    }
}

static void timantirecall_installLifecycleObserver(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        id first=[center addObserverForName:UISceneWillDeactivateNotification object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note){ timantirecall_lifecycleChanged(note); }];
        id second=[center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note){ timantirecall_lifecycleChanged(note); }];
        id third=[center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note){ timantirecall_lifecycleChanged(note); }];
        timantirecall_lifecycleObserver=@[first,second,third];
    });
}

static void timantirecall_removeToast(NSUInteger generation) {
    if (generation != timantirecall_toastGeneration) return;
    [UIView animateWithDuration:0.18 animations:^{
        timantirecall_toastView.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        if (generation != timantirecall_toastGeneration) return;
        [timantirecall_toastView removeFromSuperview];
        timantirecall_toastView = nil;
        atomic_flag_clear_explicit(&timantirecall_toastVisible, memory_order_release);
    }];
}

void timantirecall_showToast(void) {
    unsigned request = atomic_fetch_add_explicit(&timantirecall_toastRequests, 1, memory_order_relaxed);
    if (request >= 64 || atomic_flag_test_and_set_explicit(&timantirecall_toastVisible, memory_order_acquire)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        timantirecall_installLifecycleObserver();
        UIWindow *window = timantirecall_foregroundWindow();
        if (!window) { atomic_flag_clear_explicit(&timantirecall_toastVisible, memory_order_release); return; }
        timantirecall_toastGeneration += 1;
        NSUInteger generation = timantirecall_toastGeneration;
        [timantirecall_toastView removeFromSuperview];
        UILabel *label = [UILabel new];
        label.text = @"已拦截撤回";
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 1;
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
        label.layer.cornerRadius = 17.0;
        label.layer.masksToBounds = YES;
        label.userInteractionEnabled = NO;
        label.alpha = 0.0;
        timantirecall_toastView = label;
        [window addSubview:label];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        UILayoutGuide *safe = window.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-24.0],
            [label.heightAnchor constraintEqualToConstant:34.0],
            [label.widthAnchor constraintGreaterThanOrEqualToConstant:116.0],
            [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:window.leadingAnchor constant:20.0],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:window.trailingAnchor constant:-20.0]
        ]];
        [UIView animateWithDuration:0.16 animations:^{ label.alpha = 1.0; }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            timantirecall_removeToast(generation);
        });
    });
}
