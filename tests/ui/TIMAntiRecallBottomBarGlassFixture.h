#pragma once
#import "TIMAntiRecallBottomBarGlass.h"
#import "TIMAntiRecallFixture.h"

@interface QQTabBarController : UIViewController
@property(nonatomic,strong) UIView *tabBarView;
@property(nonatomic) uint64_t tabBarIndex;
+ (instancetype)appQQTabBarController;
@end
@interface QQSkinTabBar : UIView
@property(nonatomic,strong) NSMutableDictionary *barItemDic;
@property(nonatomic,strong) UIVisualEffectView *blurEffectView;
@property(nonatomic) NSUInteger timantirecall_originalLayoutCalls;
@property(nonatomic) NSUInteger timantirecall_selectionCalls;
- (void)setTabBarSelectedAtIndex:(uint64_t)index;
@end
@interface QQToolBarRootView : UIView
@property(nonatomic) int64_t iShowingIndex;
@property(nonatomic,strong) UIControl *button;
@end
FOUNDATION_EXPORT QQTabBarController * _Nullable timantirecall_glassFakeMainTabController;
