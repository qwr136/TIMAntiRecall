#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Shows a fixed, non-interactive in-app status toast when TIM is foregrounded.
// It intentionally accepts no message, UID, buffer, or account data.
void timantirecall_showToast(void);

#ifdef __cplusplus
}
#endif
