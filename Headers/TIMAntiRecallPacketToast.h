#import <Foundation/Foundation.h>
@class UIWindow;

// Native Wallet amount is a positive integer number of fen. Never persist it.
FOUNDATION_EXPORT NSString *timantirecall_packetAmountText(id minorUnits);
FOUNDATION_EXPORT void timantirecall_showPacketAmountText(NSString *text,UIWindow *window);
