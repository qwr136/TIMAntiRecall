#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL timantirecall_installPacketMonitor(void);
// Observe only an original OCMsgRecord naturally loaded by TIM; never queries history.
FOUNDATION_EXPORT void timantirecall_observeLoadedPacket(id record,NSString *owner);
