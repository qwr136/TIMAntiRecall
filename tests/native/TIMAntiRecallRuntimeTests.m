#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallWire.h"
#import "TIMAntiRecallBootstrap.h"
#include <stdlib.h>
#include <sys/stat.h>

static unsigned timantirecall_checks = 0;
static unsigned timantirecall_calls = 0;
static id timantirecall_lastCommand, timantirecall_lastBuffer, timantirecall_lastExtra;
#define CHECK(condition) do { timantirecall_checks++; if (!(condition)) { NSLog(@"FAIL line %d: %s", __LINE__, #condition); exit(1); } } while (0)

static NSData *timantirecall_var(uint64_t n) {
    NSMutableData *data = [NSMutableData data];
    do { uint8_t b = (uint8_t)(n & 127); n >>= 7; if (n) b |= 128; [data appendBytes:&b length:1]; } while (n);
    return data;
}
static NSData *timantirecall_int(unsigned f, uint64_t n) {
    NSMutableData *d = [timantirecall_var((uint64_t)f << 3) mutableCopy];
    [d appendData:timantirecall_var(n)]; return d;
}
static NSData *timantirecall_bytes(unsigned f, NSData *body) {
    NSMutableData *d = [timantirecall_var(((uint64_t)f << 3) | 2) mutableCopy];
    [d appendData:timantirecall_var(body.length)]; [d appendData:body]; return d;
}
static NSData *timantirecall_join(NSArray<NSData *> *pieces) {
    NSMutableData *d = [NSMutableData data]; for (NSData *p in pieces) [d appendData:p]; return d;
}
static NSData *timantirecall_packet(uint64_t type, uint64_t subtype, NSData *payload) {
    NSData *head = timantirecall_join(@[timantirecall_int(1, type), timantirecall_int(2, subtype)]);
    NSData *message = timantirecall_join(@[timantirecall_bytes(2, head), timantirecall_bytes(3, timantirecall_bytes(2, payload))]);
    return timantirecall_bytes(1, message);
}
static NSData *timantirecall_privatePacket(uint64_t subtype) {
    NSData *info = timantirecall_join(@[timantirecall_bytes(1, [@"u_one" dataUsingEncoding:4]),
        timantirecall_bytes(2, [@"u_two" dataUsingEncoding:4]), timantirecall_int(20, 42)]);
    return timantirecall_packet(528, subtype, timantirecall_bytes(1, info));
}
static NSData *timantirecall_groupPacket(uint64_t subtype, unsigned notifyType) {
    NSData *recall = timantirecall_bytes(3, timantirecall_int(1, 42));
    NSData *notify = timantirecall_join(@[timantirecall_int(1, notifyType), timantirecall_int(4, 9), timantirecall_bytes(11, recall)]);
    uint8_t prefix[] = {0, 0, 0, 9, 0, (uint8_t)(notify.length >> 8), (uint8_t)notify.length};
    NSData *content = timantirecall_join(@[[NSData dataWithBytes:prefix length:7], notify]);
    return timantirecall_packet(732, subtype, content);
}

@interface TIMAntiRecallTestTarget : NSObject
- (void)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra;
@end
@implementation TIMAntiRecallTestTarget
- (void)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra {
    timantirecall_calls++; timantirecall_lastCommand=command; timantirecall_lastBuffer=buffer; timantirecall_lastExtra=extra;
}
@end
@interface TIMAntiRecallTestInherited : TIMAntiRecallTestTarget @end
@implementation TIMAntiRecallTestInherited @end
@interface TIMAntiRecallTestWrong : NSObject
- (BOOL)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra;
@end
@implementation TIMAntiRecallTestWrong
- (BOOL)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra { (void)command; (void)buffer; (void)extra; return YES; }
@end

int main(void) {
    @autoreleasepool {
        NSString *temporary=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *testHome=[temporary stringByAppendingPathComponent:@"home"];
        NSString *testTmp=[temporary stringByAppendingPathComponent:@"tmp"];
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:testHome withIntermediateDirectories:YES attributes:nil error:NULL]);
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:testTmp withIntermediateDirectories:YES attributes:nil error:NULL]);
        CHECK(setenv("HOME",testHome.fileSystemRepresentation,1)==0);
        CHECK(setenv("TMPDIR",testTmp.fileSystemRepresentation,1)==0);
        CHECK(timantirecall_bootstrapEvent("constructor-test-enter"));
        NSString *bootstrap=[testHome stringByAppendingPathComponent:@"Documents/TIMAntiRecall/TIMAntiRecall-bootstrap.log"];
        CHECK([[NSString stringWithContentsOfFile:bootstrap encoding:NSUTF8StringEncoding error:NULL] containsString:@"constructor-test-enter"]);
        NSString *uuid = @"3c237fa0-5985-3376-bf98-ef1698563247";
        NSDictionary *identity=@{@"CFBundleIdentifier":@"com.tencent.tim",@"CFBundleShortVersionString":@"4.1.0",
            @"CFBundleVersion":@"4.1.0.81",@"CFBundleExecutable":@"QQ"};
        __block unsigned installCalls=0;
        void (^install)(void)=^{installCalls++;};
        for (NSArray *failure in @[@[@"CFBundleIdentifier",@"com.other",@"bundle-mismatch"],
                                 @[@"CFBundleShortVersionString",@"4.1.1",@"version-mismatch"],
                                 @[@"CFBundleVersion",@"4.1.0.82",@"build-mismatch"],
                                 @[@"CFBundleExecutable",@"Other",@"executable-mismatch"]]) {
            NSMutableDictionary *invalid=identity.mutableCopy; invalid[failure[0]]=failure[1];
            CHECK(!timantirecall_startupWithIdentity(invalid,uuid,install));
            CHECK(installCalls==0);
            NSString *log=[NSString stringWithContentsOfFile:bootstrap encoding:NSUTF8StringEncoding error:NULL];
            CHECK([log containsString:failure[2]]);
        }
        CHECK(!timantirecall_startupWithIdentity(identity,nil,install));
        CHECK(installCalls==0);
        CHECK([[NSString stringWithContentsOfFile:bootstrap encoding:NSUTF8StringEncoding error:NULL] containsString:@"uuid-mismatch"]);
        CHECK(timantirecall_startupWithIdentity(identity,uuid,install));
        CHECK(installCalls==1);
        CHECK([[NSString stringWithContentsOfFile:bootstrap encoding:NSUTF8StringEncoding error:NULL] containsString:@"identity-accepted"]);
        CHECK(timantirecall_matchesTarget(@"com.tencent.tim", @"4.1.0", @"4.1.0.81", @"QQ", uuid));
        CHECK(!timantirecall_matchesTarget(@"com.tencent.tim", @"4.1.0", @"4.1.0.81", @"QQ", nil));
        CHECK(!timantirecall_matchesTarget(@"com.tencent.mqq", @"4.1.0", @"4.1.0.81", @"QQ", uuid));
        CHECK(!timantirecall_matchesTarget(@"com.tencent.tim", @"4.1.1", @"4.1.0.81", @"QQ", uuid));
        CHECK(!timantirecall_installOnClass(Nil));
        CHECK(!timantirecall_installOnClass(TIMAntiRecallTestWrong.class));
        CHECK(!timantirecall_installOnClass(TIMAntiRecallTestInherited.class));
        CHECK(timantirecall_installOnClass(TIMAntiRecallTestTarget.class));
        CHECK(timantirecall_installOnClass(TIMAntiRecallTestTarget.class));
        CHECK(!timantirecall_installOnClass(TIMAntiRecallTestWrong.class));
        TIMAntiRecallTestTarget *target = [TIMAntiRecallTestTarget new];
        NSString *command = @"trpc.msg.olpush.OlPushService.MsgPush";
        NSObject *extra = [NSObject new];
        NSArray *blocked = @[timantirecall_privatePacket(138), timantirecall_privatePacket(139),
                             timantirecall_groupPacket(16, 7), timantirecall_groupPacket(17, 7)];
        for (NSData *data in blocked) {
            unsigned before=timantirecall_calls;
            [target onMsfPush:command msgBuffer:data pushExtraInfo:extra];
            CHECK(timantirecall_calls==before);
        }
        NSArray *forwarded = @[timantirecall_privatePacket(137), timantirecall_groupPacket(17, 8),
            timantirecall_packet(82, 0, [@"ordinary" dataUsingEncoding:4]), [NSData data], @42];
        for (id data in forwarded) {
            unsigned before=timantirecall_calls;
            [target onMsfPush:command msgBuffer:data pushExtraInfo:extra];
            CHECK(timantirecall_calls==before+1);
            CHECK(timantirecall_lastCommand==command && timantirecall_lastBuffer==data && timantirecall_lastExtra==extra);
        }
        NSData *recallList=timantirecall_bytes(11,timantirecall_bytes(3,timantirecall_int(1,42)));
        NSArray *invalidIdentities=@[[NSData data],timantirecall_int(4,0),timantirecall_bytes(4,[@"9" dataUsingEncoding:4]),
            timantirecall_join(@[timantirecall_int(4,9),timantirecall_int(4,9)])];
        for (NSData *identity in invalidIdentities) {
            NSData *notify=timantirecall_join(@[timantirecall_int(1,7),identity,recallList]);
            uint8_t prefix[]={0,0,0,9,0,(uint8_t)(notify.length>>8),(uint8_t)notify.length};
            NSData *data=timantirecall_packet(732,17,timantirecall_join(@[[NSData dataWithBytes:prefix length:7],notify]));
            unsigned count=timantirecall_calls;
            [target onMsfPush:command msgBuffer:data pushExtraInfo:extra];
            CHECK(timantirecall_calls==count+1);
            CHECK(timantirecall_lastCommand==command && timantirecall_lastBuffer==data && timantirecall_lastExtra==extra);
        }
        NSData *privateData = blocked[0];
        NSString *unrelated = @"trpc.msg.register_proxy.RegisterProxy.InfoSyncPush";
        unsigned before=timantirecall_calls;
        [target onMsfPush:unrelated msgBuffer:privateData pushExtraInfo:extra];
        CHECK(timantirecall_calls==before+1 && timantirecall_lastCommand==unrelated && timantirecall_lastBuffer==privateData);
        [target onMsfPush:nil msgBuffer:nil pushExtraInfo:nil];
        CHECK(timantirecall_calls==before+2 && timantirecall_lastCommand==nil && timantirecall_lastExtra==nil);
        for (NSData *data in blocked) {
            for (NSUInteger i=0;i<data.length;i++) {
                NSData *truncated=[data subdataWithRange:NSMakeRange(0,i)];
                CHECK(timantirecall_classifyPush(truncated.bytes,truncated.length)==TIMAntiRecallPass);
            }
        }
        NSString *startupLog=[NSString stringWithContentsOfFile:bootstrap encoding:NSUTF8StringEncoding error:NULL];
        CHECK([startupLog containsString:@"push-entered"]);
        CHECK([startupLog containsString:@"olpush-entered-data"]);
        CHECK([startupLog containsString:@"blocked-private-recall"]);
        CHECK([startupLog containsString:@"blocked-group-recall"]);
        CHECK(![startupLog containsString:@"u_one"] && ![startupLog containsString:@"u_two"]);
        CHECK([NSFileManager.defaultManager removeItemAtPath:temporary error:NULL]);
        NSLog(@"PASS %u native runtime/forwarding/ABI/startup checks; device untested",timantirecall_checks);
    }
    return 0;
}
