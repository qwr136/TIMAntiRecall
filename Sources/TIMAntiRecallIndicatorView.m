#import "TIMAntiRecallIndicatorView.h"

@interface TIMAntiRecallIndicatorView ()
@property(nonatomic,strong) UILabel *timantirecall_label;
@property(nonatomic) BOOL timantirecall_showTime;
@property(nonatomic) NSTimeInterval timantirecall_time;
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
- (void)timantirecall_setCaptureTime:(NSTimeInterval)time showTime:(BOOL)show {
    show=show && time>0;
    if(self.timantirecall_time==time && self.timantirecall_showTime==show)return;
    self.timantirecall_time=time;self.timantirecall_showTime=show;
    if(!show){self.timantirecall_label.text=@"已撤回";return;}
    static NSDateFormatter *format;static dispatch_once_t once;
    dispatch_once(&once,^{format=[NSDateFormatter new];format.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];format.dateFormat=@"HH:mm:ss";});
    self.timantirecall_label.text=[@"已撤回 · " stringByAppendingString:[format stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]]];
}
- (void)timantirecall_fitToBounds:(CGRect)bounds {
    self.frame=CGRectInset(bounds,3.0,1.0);
    CGFloat width=self.timantirecall_showTime?MIN(148,MAX(48,self.bounds.size.width-8)):48;
    self.timantirecall_label.frame=CGRectMake(MAX(4,self.bounds.size.width-width-6),
        MAX(1,self.bounds.size.height-20),width,16);
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {(void)point;(void)event;return nil;}
@end
