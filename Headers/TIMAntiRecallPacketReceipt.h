#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL timantirecall_walletTrustedClass(Class cls);
@interface TIMAntiRecallPacketReceipt : NSObject
- (instancetype)initWithBill:(NSString *)bill;
- (BOOL)timantirecall_confirmed;
- (BOOL)timantirecall_failed;
@end
