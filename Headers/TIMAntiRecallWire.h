#pragma once
#include <stddef.h>
#include <stdint.h>

typedef enum {
    TIMAntiRecallPass = 0,
    TIMAntiRecallPrivate = 1,
    TIMAntiRecallGroup = 2
} TIMAntiRecallDecision;

// Unknown, ambiguous, oversized and malformed packets are always forwarded.
TIMAntiRecallDecision timantirecall_classifyPush(const uint8_t *bytes, size_t length);
