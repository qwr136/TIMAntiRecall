#pragma once
#import <UIKit/UIKit.h>

@interface TIMAntiRecallIndicatorView : UIView
- (void)timantirecall_setCaptureTime:(NSTimeInterval)time showTime:(BOOL)show;
- (void)timantirecall_fitToBounds:(CGRect)bounds;
@end
