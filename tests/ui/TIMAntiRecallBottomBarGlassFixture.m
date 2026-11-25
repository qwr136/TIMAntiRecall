#import "TIMAntiRecallBottomBarGlassFixture.h"
QQTabBarController *timantirecall_glassFakeMainTabController;
@implementation QQTabBarController
+ (instancetype)appQQTabBarController {return timantirecall_glassFakeMainTabController;}
@end
@implementation QQSkinTabBar
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];if(self){
        self.barItemDic=[NSMutableDictionary dictionary];
        self.blurEffectView=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        self.blurEffectView.frame=self.bounds;self.blurEffectView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.blurEffectView];
    }return self;
}
- (void)layoutSubviews {[super layoutSubviews];self.timantirecall_originalLayoutCalls++;self.blurEffectView.frame=self.bounds;}
- (void)setTabBarSelectedAtIndex:(uint64_t)index {self.timantirecall_selectionCalls++;timantirecall_glassFakeMainTabController.tabBarIndex=index;}
@end
@implementation QQToolBarRootView
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];if(self){self.button=[UIControl new];self.button.frame=self.bounds;self.button.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self addSubview:self.button];}
    return self;
}
@end
