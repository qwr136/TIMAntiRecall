#import "TIMAntiRecallTrace.h"
#import "TIMAntiRecallSettings.h"
#include <stdatomic.h>

void timantirecall_traceEvent(NSString *event) {
    if(![timantirecall_settings() timantirecall_packetDiagnostics])return;
    static _Atomic(unsigned) count;
    if(atomic_fetch_add_explicit(&count,1,memory_order_relaxed)>=192)return;
    static dispatch_queue_t queue;static dispatch_once_t once;
    dispatch_once(&once,^{queue=dispatch_queue_create("com.minis.timantirecall.packet-diagnostic",DISPATCH_QUEUE_SERIAL);});
    NSString *safe=@"invalid";
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.:@?"];
    if([event isKindOfClass:NSString.class]&&event.length<=160&&[event rangeOfCharacterFromSet:allowed.invertedSet].location==NSNotFound)safe=[event copy];
    dispatch_async(queue,^{
        @autoreleasepool {
            NSArray<NSURL *> *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
            NSURL *directory=[documents.firstObject URLByAppendingPathComponent:@"TIMAntiRecall" isDirectory:YES];
            if(!directory||![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL])return;
            NSURL *url=[directory URLByAppendingPathComponent:@"TIMAntiRecall-packets.log"];
            NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:NULL];
            if([attributes[NSFileSize] unsignedLongLongValue]>96*1024){
                NSURL *old=[directory URLByAppendingPathComponent:@"TIMAntiRecall-packets.log.1"];
                [NSFileManager.defaultManager removeItemAtURL:old error:NULL];
                if(![NSFileManager.defaultManager moveItemAtURL:url toURL:old error:NULL])return;
            }
            NSString *line=[NSString stringWithFormat:@"%@ %@\n",NSDate.date,safe];
            NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
            NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:url.path];
            if(handle){
                if([handle seekToEndReturningOffset:NULL error:NULL])[handle writeData:data error:NULL];
                [handle closeAndReturnError:NULL];
            }else [data writeToURL:url options:NSDataWritingAtomic error:NULL];
            [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:url.path error:NULL];
        }
    });
}
