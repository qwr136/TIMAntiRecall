#pragma once
#import <Foundation/Foundation.h>
// Arms only for the native route initiated by this plugin. No coordinate taps.
FOUNDATION_EXPORT void timantirecall_beginPacketOpen(id presenter, Class walletService, BOOL (^isValid)(void));
