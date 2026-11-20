#pragma once
#import <Foundation/Foundation.h>
@class UIView;
FOUNDATION_EXPORT BOOL timantirecall_installMessageReplay(void);
FOUNDATION_EXPORT void timantirecall_updateReplayRow(UIView *row,NSString *boundOwner);
FOUNDATION_EXPORT void timantirecall_clearReplayRow(UIView *row);
#ifdef TIMANTIRECALL_UI_TEST
#import <CoreGraphics/CoreGraphics.h>
FOUNDATION_EXPORT BOOL timantirecall_testReplayCapture(UIView *row,CGPoint point,NSTimeInterval time);
FOUNDATION_EXPORT BOOL timantirecall_testReplayComplete(UIView *row,CGPoint point);
#endif
