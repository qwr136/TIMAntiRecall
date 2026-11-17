#import "TIMAntiRecallRuntime.h"
#import <stdatomic.h>

void timantirecall_logEvent(NSString *event) {
#ifdef TIMANTIRECALL_NATIVE_TEST
    (void)event;
#else
    static atomic_uint events = 0;
    if (atomic_fetch_add_explicit(&events, 1, memory_order_relaxed) >= 64) return;
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.minis.timantirecall.status", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(queue, ^{
        @autoreleasepool {
            NSArray<NSURL *> *documents = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
            NSURL *directory = [documents.firstObject URLByAppendingPathComponent:@"TIMAntiRecall" isDirectory:YES];
            if (!directory) return;
            NSFileManager *manager = NSFileManager.defaultManager;
            if (![manager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:NULL]) return;
            NSString *path = [[directory URLByAppendingPathComponent:@"TIMAntiRecall.log"] path];
            NSDictionary *attributes = [manager attributesOfItemAtPath:path error:NULL];
            if ([attributes[NSFileSize] unsignedLongLongValue] > 128 * 1024) {
                NSString *previous = [path stringByAppendingString:@".1"];
                [manager removeItemAtPath:previous error:NULL];
                [manager moveItemAtPath:path toPath:previous error:NULL];
            }
            NSData *line = [[NSString stringWithFormat:@"%@ %@\n", NSDate.date, event] dataUsingEncoding:NSUTF8StringEncoding];
            @try {
                NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
                if (file) { [file seekToEndOfFile]; [file writeData:line]; [file closeFile]; }
                else { [line writeToFile:path atomically:YES]; }
            } @catch (__unused NSException *exception) {
                // Logging failure must not change message delivery.
            }
        }
    });
#endif
}
