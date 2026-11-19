#pragma once
#import <Foundation/Foundation.h>
// Main thread. YES only with a verified Wallet service and both callback slots idle.
FOUNDATION_EXPORT BOOL timantirecall_walletCanAcceptPacket(Class walletService);
// Reject a popup still in native success animation or a known verification path.
FOUNDATION_EXPORT BOOL timantirecall_walletPopupCanRetire(id view);
FOUNDATION_EXPORT BOOL timantirecall_walletPopupMatchesBill(id view, NSString *bill);
FOUNDATION_EXPORT BOOL timantirecall_installPacketFinish(Class walletService);
// Used only at the validated auto-open action boundary, never for a manual open.
FOUNDATION_EXPORT void timantirecall_armPacketFinish(id view, NSString *bill, BOOL (^valid)(void), void (^closed)(void));
FOUNDATION_EXPORT void timantirecall_disarmPacketFinish(void);
