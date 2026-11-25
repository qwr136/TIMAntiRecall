#pragma once
#import <Foundation/Foundation.h>
// Immutable, bounded descriptions only. Never retain received payload objects.
FOUNDATION_EXPORT NSDictionary *timantirecall_richReplaySnapshot(id record);
// Creates fresh native message elements; returns nil for photos (native upload only).
FOUNDATION_EXPORT NSArray *timantirecall_richReplayElements(NSDictionary *snapshot);
// Submission, not delivery confirmation. Missing originals use TIM's native original-image downloader, then invoke completion only after file validation.
FOUNDATION_EXPORT BOOL timantirecall_richReplaySend(id service,id contact,id record,NSDictionary *snapshot);
FOUNDATION_EXPORT BOOL timantirecall_richReplaySendWithPhotoDownload(id service,id contact,id record,NSDictionary *snapshot,void (^completion)(NSDictionary *file,NSNumber *subtype),BOOL (^shouldContinue)(void));
FOUNDATION_EXPORT BOOL timantirecall_richReplaySendDownloadedPhoto(id service,id contact,id record,NSDictionary *file,NSNumber *subtype);
