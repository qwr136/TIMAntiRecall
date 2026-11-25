#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL timantirecall_installBottomBarGlass(void);
#ifdef TIMANTIRECALL_UI_TEST
@class UIView;
FOUNDATION_EXPORT BOOL timantirecall_testBottomBarGlass(UIView *bar);
FOUNDATION_EXPORT CGRect timantirecall_testBottomBarGlassLensFrame(UIView *bar);
#endif
