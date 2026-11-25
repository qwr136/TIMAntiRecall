#pragma once
#import "TIMAntiRecallBottomBarGlass.h"
#import "TIMAntiRecallFixture.h"

NS_ASSUME_NONNULL_BEGIN

@interface QQTabBarController : UIViewController
@property(nonatomic,strong) UIView * _Nullable tabBarView;
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
@property(nonatomic,strong) UIImageView *timantirecall_fixtureIcon;
@property(nonatomic,strong) UILabel *timantirecall_fixtureTitle;
@property(nonatomic,strong) UILabel * _Nullable timantirecall_fixtureBadge;
- (void)timantirecall_applyFixtureSelected:(BOOL)selected;
@end
FOUNDATION_EXPORT QQTabBarController * _Nullable timantirecall_glassFakeMainTabController;

NS_ASSUME_NONNULL_END
