#pragma once
#import <Foundation/Foundation.h>
// Arms only for the native route initiated by this plugin. No coordinate taps.
FOUNDATION_EXPORT void timantirecall_beginPacketOpen(id presenter, Class walletService, BOOL (^isValid)(void));
FOUNDATION_EXPORT void timantirecall_beginPacketOpenWithReceipt(id presenter, Class walletService, BOOL (^isValid)(void), BOOL (^didReceive)(void));
FOUNDATION_EXPORT BOOL timantirecall_hasPendingPacketUI(void);
@class TIMAntiRecallPacketReceipt;
FOUNDATION_EXPORT void timantirecall_beginPacketOpenWithFailure(id presenter, Class walletService, BOOL (^isValid)(void), BOOL (^didReceive)(void), BOOL (^didFail)(void), NSString *bill, TIMAntiRecallPacketReceipt *nativeReceipt);
