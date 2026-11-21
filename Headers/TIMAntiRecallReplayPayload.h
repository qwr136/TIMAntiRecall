#pragma once
#import <Foundation/Foundation.h>
// Immutable, bounded descriptions only. Never retain received payload objects.
FOUNDATION_EXPORT NSDictionary *timantirecall_richReplaySnapshot(id record);
// Creates fresh native message elements; returns nil for photos (native upload only).
FOUNDATION_EXPORT NSArray *timantirecall_richReplayElements(NSDictionary *snapshot);
// Submission, not delivery confirmation. No retries, editor mutation or record mutation.
FOUNDATION_EXPORT BOOL timantirecall_richReplaySend(id service,id contact,id record,NSDictionary *snapshot);
