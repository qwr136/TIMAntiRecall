#pragma once
#import <UIKit/UIKit.h>
@interface TIMAntiRecallPreferencesController : UITableViewController
- (instancetype)initWithOwner:(NSString *)owner chat:(NSDictionary *)chat;
@end
FOUNDATION_EXPORT BOOL timantirecall_installPreferences(void);
