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
- (void)setTabBarSelectedAtIndex:(uint64_t)index {self.timantirecall_selectionCalls++;timantirecall_glassFakeMainTabController.tabBarIndex=index;for(QQToolBarRootView *item in self.barItemDic.allValues)[item timantirecall_applyFixtureSelected:item.iShowingIndex==(int64_t)index];}
@end
@implementation QQToolBarRootView
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];if(self){
        self.button=[UIControl new];self.button.frame=self.bounds;self.button.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.button.backgroundColor=UIColor.clearColor;[self addSubview:self.button];
        NSArray *symbols=@[@"bubble.left.and.bubble.right.fill",@"person.2.fill",@"person.crop.circle.fill"];
        NSArray *titles=@[@"消息",@"联系人",@"我的"];
        UIImage *symbol=[UIImage systemImageNamed:symbols[(NSUInteger)MAX(0,MIN(2,self.iShowingIndex))]];
        self.timantirecall_fixtureIcon=[[UIImageView alloc] initWithImage:symbol];self.timantirecall_fixtureIcon.contentMode=UIViewContentModeScaleAspectFit;self.timantirecall_fixtureIcon.frame=CGRectMake((CGRectGetWidth(frame)-25)*0.5,5,25,23);self.timantirecall_fixtureIcon.tag=501;[self.button addSubview:self.timantirecall_fixtureIcon];
        self.timantirecall_fixtureTitle=[[UILabel alloc] initWithFrame:CGRectMake(0,31,CGRectGetWidth(frame),18)];self.timantirecall_fixtureTitle.text=titles[(NSUInteger)MAX(0,MIN(2,self.iShowingIndex))];self.timantirecall_fixtureTitle.textAlignment=NSTextAlignmentCenter;self.timantirecall_fixtureTitle.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];self.timantirecall_fixtureTitle.tag=502;[self.button addSubview:self.timantirecall_fixtureTitle];
        if(self.iShowingIndex==0||self.iShowingIndex==1){UIView *badge=[UIView new];badge.backgroundColor=[UIColor colorWithRed:1 green:0.08 blue:0.28 alpha:1];badge.layer.cornerRadius=8.5;badge.frame=CGRectMake(CGRectGetMidX(self.timantirecall_fixtureIcon.frame)+5,3,17,17);[self.button addSubview:badge];self.timantirecall_fixtureBadge=[[UILabel alloc] initWithFrame:badge.bounds];self.timantirecall_fixtureBadge.text=self.iShowingIndex==0?@"99+":@"3";self.timantirecall_fixtureBadge.textAlignment=NSTextAlignmentCenter;self.timantirecall_fixtureBadge.textColor=UIColor.whiteColor;self.timantirecall_fixtureBadge.font=[UIFont systemFontOfSize:7 weight:UIFontWeightBold];[badge addSubview:self.timantirecall_fixtureBadge];}
        [self timantirecall_applyFixtureSelected:self.iShowingIndex==1];
    }return self;
}
- (void)timantirecall_applyFixtureSelected:(BOOL)selected {
    NSUInteger index=(NSUInteger)MAX(0,MIN(2,self.iShowingIndex));
    NSArray *symbols=@[@"bubble.left.and.bubble.right.fill",@"person.2.fill",@"person.crop.circle.fill"];
    NSArray *titles=@[@"消息",@"联系人",@"我的"];
    self.timantirecall_fixtureIcon.image=[UIImage systemImageNamed:symbols[index]];
    self.timantirecall_fixtureTitle.text=titles[index];
    if(index<2) {
        UIView *badge=self.timantirecall_fixtureBadge.superview;
        if(!badge){badge=[UIView new];badge.backgroundColor=[UIColor colorWithRed:1 green:0.08 blue:0.28 alpha:1];badge.layer.cornerRadius=8.5;[self.button addSubview:badge];self.timantirecall_fixtureBadge=[[UILabel alloc] initWithFrame:badge.bounds];self.timantirecall_fixtureBadge.textAlignment=NSTextAlignmentCenter;self.timantirecall_fixtureBadge.textColor=UIColor.whiteColor;self.timantirecall_fixtureBadge.font=[UIFont systemFontOfSize:7 weight:UIFontWeightBold];[badge addSubview:self.timantirecall_fixtureBadge];}
        badge.frame=CGRectMake(CGRectGetMidX(self.timantirecall_fixtureIcon.frame)+5,3,17,17);self.timantirecall_fixtureBadge.frame=badge.bounds;
        self.timantirecall_fixtureBadge.text=index==0?@"99+":@"3";
    } else { [self.timantirecall_fixtureBadge.superview removeFromSuperview];self.timantirecall_fixtureBadge=nil; }
    UIColor *color=selected?[UIColor colorWithRed:0.10 green:0.62 blue:1 alpha:1]:UIColor.whiteColor;
    self.timantirecall_fixtureIcon.tintColor=color;self.timantirecall_fixtureTitle.textColor=color;
}
@end
