#pragma once
#import <Foundation/Foundation.h>
typedef void (^TIMAntiRecallSilentReceipt)(NSDictionary *,NSError *);
// Main queue only; checks both native service slots and the low Wallet slot.
FOUNDATION_EXPORT BOOL timantirecall_silentPacketReady(Class service);
// invoke must forward the original router with its exact record and this callback.
FOUNDATION_EXPORT BOOL timantirecall_beginSilentPacket(Class service,NSString *bill,
    BOOL (^valid)(void),void (^finished)(NSString *phase,NSString *amountText),
    void (^invoke)(TIMAntiRecallSilentReceipt callback));
