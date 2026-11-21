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

typedef struct {
    uint64_t sequence, group, random, time;
    unsigned kind, hasRandom, hasTime;
    char from[129], to[129], author[129];
} TIMAntiRecallWireEvent;
// Exact recall actor: private info.from or group Notify[11].OperatorUid[1].
// Missing/malformed/duplicate actors return zero and leave actor empty.
int timantirecall_extractRecallActor(const uint8_t *bytes, size_t length, char actor[129]);
// Copies bounded identities only; zero means ambiguous/unsupported. Never changes classifier decisions.
// Scope extraction is independent of mark-only author/time/random fields.
// It lets a disabled group pass even if the notification has no author UID.
int timantirecall_extractRecallScope(const uint8_t *bytes, size_t length,
                                    TIMAntiRecallWireEvent *scope);
// Cleanup-only: group author may be absent. Never use these targets to add marks.
size_t timantirecall_extractRecallCleanupTargets(const uint8_t *bytes, size_t length,
                                               TIMAntiRecallWireEvent *events, size_t capacity);
size_t timantirecall_extractRecallEvents(const uint8_t *bytes, size_t length,
                                         TIMAntiRecallWireEvent *events, size_t capacity);
