#import "TIMAntiRecallReplayTrace.h"
#import "TIMAntiRecallSettings.h"
#include <math.h>

static dispatch_queue_t timantirecall_replayTraceQueue(void) {
    static dispatch_queue_t queue;static dispatch_once_t once;
    dispatch_once(&once,^{queue=dispatch_queue_create("com.minis.timantirecall.replay-diagnostic",DISPATCH_QUEUE_SERIAL);});return queue;
}
static NSObject *timantirecall_replayTraceLock(void) {
    static NSObject *lock;static dispatch_once_t once;dispatch_once(&once,^{lock=[NSObject new];});return lock;
}
static NSUInteger timantirecall_replayTraceGeneration=1;
static NSMutableDictionary<NSData *,NSNumber *> *timantirecall_replayTraceSeen;
static unsigned timantirecall_replayTraceCount;
NSURL *timantirecall_replayTraceURL(void) {
    NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documents URLByAppendingPathComponent:@"TIMAntiRecall" isDirectory:YES] URLByAppendingPathComponent:@"TIMAntiRecall-replay.log"];
}
void timantirecall_replayTraceStartSession(void) {
    @synchronized(timantirecall_replayTraceLock()) { timantirecall_replayTraceGeneration++; }
    dispatch_sync(timantirecall_replayTraceQueue(),^{
        timantirecall_replayTraceSeen=[NSMutableDictionary dictionary];timantirecall_replayTraceCount=0;
        NSURL *url=timantirecall_replayTraceURL();
        [NSFileManager.defaultManager removeItemAtURL:url error:NULL];
        [NSFileManager.defaultManager removeItemAtURL:[url URLByAppendingPathExtension:@"1"] error:NULL];
    });
    if([timantirecall_settings() timantirecall_replayDiagnostics]) {
        timantirecall_replayTrace(@"settings",@{@"reason":@"session-start"});
        dispatch_sync(timantirecall_replayTraceQueue(),^{});
    }
}
static BOOL timantirecall_replayTraceToken(id value) {
    if(![value isKindOfClass:NSString.class]||[value length]>160)return NO;
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.:$"];
    return [value rangeOfCharacterFromSet:allowed.invertedSet].location==NSNotFound;
}
void timantirecall_replayTrace(NSString *stage,NSDictionary *fields) {
    if(![timantirecall_settings() timantirecall_replayDiagnostics])return;
    static NSSet *stages,*names,*numbers;static dispatch_once_t once;
    dispatch_once(&once,^{
        stages=[NSSet setWithArray:@[@"sync",@"attach",@"gate",@"text",@"touch",@"capture",@"action",@"send",@"settings"]];
        names=[NSSet setWithArray:@[@"reason",@"field",@"shape",@"rowClass",@"hostClass",@"contentClass",@"controllerClass",@"modelClass",@"valueClass",@"valueKind"]];
        numbers=[NSSet setWithArray:@[@"samples",@"tapCount",@"state",@"accepted",@"x",@"y",@"hw",@"hh",@"bx",@"by",@"bw",@"bh"]];
    });
    if(![stages containsObject:stage])return;
    NSMutableDictionary *safe=[@{@"stage":stage,@"schema":@"replay-boxed-zero-v1"} mutableCopy];
    for(id key in fields) {
        if([names containsObject:key]&&timantirecall_replayTraceToken(fields[key]))safe[key]=fields[key];
        else if([numbers containsObject:key]&&[fields[key] isKindOfClass:NSNumber.class]) {
            double value=[fields[key] doubleValue];if(isfinite(value)&&fabs(value)<=100000)safe[key]=fields[key];
        }
    }
    NSData *fingerprint=[NSJSONSerialization dataWithJSONObject:safe options:NSJSONWritingSortedKeys error:NULL];
    if(!fingerprint)return;
    __block NSUInteger generation=0;
    @synchronized(timantirecall_replayTraceLock()) { generation=timantirecall_replayTraceGeneration; }
    dispatch_async(timantirecall_replayTraceQueue(),^{@autoreleasepool {
        __block BOOL current=NO;
        @synchronized(timantirecall_replayTraceLock()) {
            current=generation==timantirecall_replayTraceGeneration&&[timantirecall_settings() timantirecall_replayDiagnostics];
        }
        if(!current)return;
        if(!timantirecall_replayTraceSeen)timantirecall_replayTraceSeen=[NSMutableDictionary dictionary];
        unsigned repetitions=[timantirecall_replayTraceSeen[fingerprint] unsignedIntValue];
        if(timantirecall_replayTraceCount>=192||repetitions>=4)return;
        timantirecall_replayTraceSeen[fingerprint]=@(repetitions+1);timantirecall_replayTraceCount++;
        safe[@"time"]=@([NSDate.date timeIntervalSince1970]);
        NSData *json=[NSJSONSerialization dataWithJSONObject:safe options:NSJSONWritingSortedKeys error:NULL];
        if(!json)return;
        NSMutableData *line=[json mutableCopy];[line appendBytes:"\n" length:1];
        NSURL *url=timantirecall_replayTraceURL(),*directory=url.URLByDeletingLastPathComponent;
        if(!url||![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL])return;
        unsigned long long size=[[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:NULL][NSFileSize] unsignedLongLongValue];
        if(size+line.length>96*1024) {
            NSURL *old=[url URLByAppendingPathExtension:@"1"];
            [NSFileManager.defaultManager removeItemAtURL:old error:NULL];
            [NSFileManager.defaultManager moveItemAtURL:url toURL:old error:NULL];
        }
        NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:url.path];
        if(handle) {
            if([handle seekToEndReturningOffset:NULL error:NULL])[handle writeData:line error:NULL];
            [handle closeAndReturnError:NULL];
        }else [line writeToURL:url options:NSDataWritingAtomic error:NULL];
        [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:url.path error:NULL];
    }});
}
NSURL *timantirecall_replayTraceExport(void) {
    __block NSURL *result=nil;
    dispatch_sync(timantirecall_replayTraceQueue(),^{
        NSURL *source=timantirecall_replayTraceURL();
        unsigned long long size=[[NSFileManager.defaultManager attributesOfItemAtPath:source.path error:NULL][NSFileSize] unsignedLongLongValue];
        if(!size||size>96*1024)return;
        NSData *data=[NSData dataWithContentsOfURL:source];
        NSURL *target=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"TIMAntiRecall-replay.log"]];
        if([data writeToURL:target options:NSDataWritingAtomic error:NULL]) {
            [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:target.path error:NULL];result=target;
        }
    });
    return result;
}
