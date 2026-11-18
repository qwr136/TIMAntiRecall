#import "TIMAntiRecallIndicatorView.h"

@interface TIMAntiRecallIndicatorView ()
@property(nonatomic,strong) UILabel *timantirecall_label;
@end
@implementation TIMAntiRecallIndicatorView
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];
    if(self) {
        self.userInteractionEnabled=NO;
        self.isAccessibilityElement=NO;
        self.backgroundColor=UIColor.clearColor;
        UIColor *red=[UIColor colorWithRed:0.80 green:0.25 blue:0.36 alpha:1];
        self.layer.borderColor=[red colorWithAlphaComponent:0.78].CGColor;
        self.layer.borderWidth=0.8;
        self.layer.cornerRadius=9.0;
        self.timantirecall_label=[UILabel new];
        self.timantirecall_label.text=@"已撤回";
        self.timantirecall_label.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        self.timantirecall_label.textColor=red;
        self.timantirecall_label.userInteractionEnabled=NO;
        self.timantirecall_label.isAccessibilityElement=NO;
        self.timantirecall_label.textAlignment=NSTextAlignmentRight;
        self.timantirecall_label.backgroundColor=[UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.9];
        self.timantirecall_label.layer.cornerRadius=3;
        self.timantirecall_label.layer.masksToBounds=YES;
        [self addSubview:self.timantirecall_label];
        self.accessibilityIdentifier=@"TIMAntiRecall.rowMark";
    }
    return self;
}
- (void)timantirecall_fitToBounds:(CGRect)bounds {
    self.frame=CGRectInset(bounds,3.0,1.0);
    self.timantirecall_label.frame=CGRectMake(MAX(4,self.bounds.size.width-54),
        MAX(1,self.bounds.size.height-20),48,16);
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {(void)point;(void)event;return nil;}
@end
