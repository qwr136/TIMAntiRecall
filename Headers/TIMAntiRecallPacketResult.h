#pragma once
#import <Foundation/Foundation.h>
// Locates a new native Wallet detail page for the same bill and dispatches its
// verified registered left-button action. It never infers receipt from text.
@interface TIMAntiRecallPacketResult : NSObject
- (instancetype)initWithPresenter:(id)presenter walletService:(Class)service bill:(NSString *)bill;
- (BOOL)timantirecall_refresh;
- (BOOL)timantirecall_returnToOrigin;
- (BOOL)timantirecall_originRestored;
- (BOOL)timantirecall_hasOwnedPage;
@property(nonatomic,copy) void (^timantirecall_log)(NSString *phase,const char *event);
@end
