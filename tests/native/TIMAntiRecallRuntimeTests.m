#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallWire.h"
#import "TIMAntiRecallBootstrap.h"
#import "TIMAntiRecallImage.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallSettings.h"
#include <stdlib.h>
#include <string.h>
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
static NSData *timantirecall_privateActorPacket(uint64_t subtype, NSString *actor, NSString *to, uint64_t sequence) {
    NSMutableArray *pieces=[NSMutableArray arrayWithObjects:timantirecall_bytes(2,[to dataUsingEncoding:4]),timantirecall_int(20,sequence),nil];
    if(actor)[pieces addObject:timantirecall_bytes(1,[actor dataUsingEncoding:4])];
    return timantirecall_packet(528,subtype,timantirecall_bytes(1,timantirecall_join(pieces)));
}
static NSData *timantirecall_privatePacket(uint64_t subtype) {
    return timantirecall_privateActorPacket(subtype,@"u_one",@"u_two",42);
}
static NSData *timantirecall_groupActorPacket(uint64_t subtype, unsigned notifyType, NSString *actor, NSString *author, uint64_t sequence) {
    NSData *message=timantirecall_int(1,sequence);
    if(author)message=timantirecall_join(@[message,timantirecall_bytes(6,[author dataUsingEncoding:4])]);
    NSData *recall=timantirecall_bytes(3,message);
    if(actor)recall=timantirecall_join(@[timantirecall_bytes(1,[actor dataUsingEncoding:4]),recall]);
    NSData *notify=timantirecall_join(@[timantirecall_int(1,notifyType),timantirecall_int(4,9),timantirecall_bytes(11,recall)]);
    uint8_t prefix[]={0,0,0,9,0,(uint8_t)(notify.length>>8),(uint8_t)notify.length};
    return timantirecall_packet(732,subtype,timantirecall_join(@[[NSData dataWithBytes:prefix length:7],notify]));
}
static NSData *timantirecall_groupPacket(uint64_t subtype, unsigned notifyType) {
    // Operator is explicit and independent of the recalled message's author.
    return timantirecall_groupActorPacket(subtype,notifyType,@"third_actor",@"u_one",42);
}

@interface OCInitSessionConfig : NSObject
@property(nonatomic,copy) NSString *selfUid;
@end
@implementation OCInitSessionConfig @end
static unsigned timantirecall_initCalls, timantirecall_closeCalls;
static NSArray *timantirecall_sessionArguments;
@interface TIMAntiRecallTestTarget : NSObject
- (void)init:(id)config depends:(id)depends dispatcherDepends:(id)dispatcher listener:(id)listener __attribute__((objc_method_family(none)));
- (void)close:(id)callback;
- (void)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra;
@end
@implementation TIMAntiRecallTestTarget
- (void)init:(id)config depends:(id)depends dispatcherDepends:(id)dispatcher listener:(id)listener {
    timantirecall_initCalls++;
    timantirecall_sessionArguments=@[config?:NSNull.null,depends?:NSNull.null,dispatcher?:NSNull.null,listener?:NSNull.null];
}
- (void)close:(id)callback {
    timantirecall_closeCalls++;timantirecall_sessionArguments=@[callback?:NSNull.null];
}
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

static void timantirecall_assertForward(TIMAntiRecallTestTarget *target, id command, id data, id extra) {
    unsigned before=timantirecall_calls;
    [target onMsfPush:command msgBuffer:data pushExtraInfo:extra];
    CHECK(timantirecall_calls==before+1);
    CHECK(timantirecall_lastCommand==command && timantirecall_lastBuffer==data && timantirecall_lastExtra==extra);
}
static void timantirecall_testOwnRecall(TIMAntiRecallTestTarget *target, NSString *command, id extra) {
    TIMAntiRecallMarkStore *store=timantirecall_sharedMarks();
    for(NSNumber *subtype in @[@138,@139,@16,@17]) {
        BOOL group=subtype.unsignedIntValue<100;
        NSData *data=group?timantirecall_groupActorPacket(subtype.unsignedIntValue,7,@"u_two",@"u_one",73):
            timantirecall_privateActorPacket(subtype.unsignedIntValue,@"u_two",@"u_one",73);
        CHECK(timantirecall_classifyPush(data.bytes,data.length)==(group?TIMAntiRecallGroup:TIMAntiRecallPrivate));
        [store timantirecall_clear];
        timantirecall_assertForward(target,command,data,extra);
        CHECK([store timantirecall_eventsForOwner:@"u_two"].count==0);
    }
    // A third-party operator recalling our message is still intercepted. An
    // absent author only prevents display; it must not bypass the network gate.
    for(id author in @[@"u_two",NSNull.null]) {
        NSData *data=timantirecall_groupActorPacket(17,7,@"third_actor",author==NSNull.null?nil:author,74);
        CHECK(timantirecall_classifyPush(data.bytes,data.length)==TIMAntiRecallGroup);
        unsigned before=timantirecall_calls;
        [target onMsfPush:command msgBuffer:data pushExtraInfo:extra];
        CHECK(timantirecall_calls==before);
    }
    for(NSData *data in @[timantirecall_privateActorPacket(138,nil,@"u_two",75),
                          timantirecall_groupActorPacket(17,7,nil,@"u_two",75)]) {
        timantirecall_assertForward(target,command,data,extra);
    }
    // Old group marks contain no operator. A hidden/ambiguous mark must be
    // removed even though displayCandidateForIdentity returns nil.
    [store timantirecall_clear];
    NSDictionary *legacy=@{@"kind":@2,@"group":@9,@"seq":@76,@"author":@"u_one",@"displayAmbiguous":@YES};
    NSDictionary *neighbor=@{@"kind":@2,@"group":@9,@"seq":@77,@"author":@"u_one"};
    NSDictionary *identity=@{@"owner":@"u_two",@"kind":@2,@"group":@9,@"seq":@76,@"author":@"u_one",@"id":@176,@"random":@3,@"time":@1700000000};
    [store timantirecall_addEvents:@[legacy,neighbor] owner:@"u_two"];
    CHECK([store timantirecall_containsRecallEventForIdentity:identity]);
    CHECK([store timantirecall_displayCandidateForIdentity:identity]==nil);
    timantirecall_assertForward(target,command,timantirecall_groupActorPacket(17,7,@"u_two",nil,76),extra);
    CHECK(![store timantirecall_containsRecallEventForIdentity:identity]);
    CHECK([store timantirecall_eventsForOwner:@"u_two"].count==1);
    CHECK([[store timantirecall_eventsForOwner:@"u_two"].firstObject[@"seq"] isEqual:@77]);
    [store timantirecall_clear];
    NSError *error=nil;
    CHECK([timantirecall_settings() timantirecall_updateOptions:@{@"enabled":@NO} error:&error]);
    timantirecall_assertForward(target,command,timantirecall_privatePacket(138),extra);
    timantirecall_assertForward(target,command,timantirecall_groupPacket(17,7),extra);
    CHECK([store timantirecall_eventsForOwner:@"u_two"].count==0);
    CHECK([timantirecall_settings() timantirecall_updateOptions:@{@"enabled":@YES} error:&error]);
    [target close:extra];
    CHECK(timantirecall_closeCalls==1 && timantirecall_sessionArguments.firstObject==extra);
    CHECK(timantirecall_sessionOwner(target)==nil);
    timantirecall_assertForward(target,command,timantirecall_privatePacket(138),extra);
    timantirecall_assertForward(target,command,timantirecall_groupPacket(17,7),extra);
    CHECK([store timantirecall_eventsForOwner:@"u_two"].count==0);
}

static NSData *timantirecall_imageHeader(uint32_t filetype, cpu_type_t cpu, cpu_subtype_t subtype,
                                           BOOL duplicateUUID, BOOL invalidCommand) {
    uint32_t count=duplicateUUID?2:1;
    size_t commandBytes=count*sizeof(struct uuid_command);
    size_t total=sizeof(struct mach_header_64)+commandBytes;
    NSMutableData *data=[NSMutableData dataWithLength:total];
    struct mach_header_64 *header=data.mutableBytes;
    header->magic=MH_MAGIC_64; header->cputype=cpu; header->cpusubtype=subtype;
    header->filetype=filetype; header->ncmds=count; header->sizeofcmds=(uint32_t)commandBytes;
    uint8_t bytes[16]; [[[NSUUID alloc] initWithUUIDString:@"3c237fa0-5985-3376-bf98-ef1698563247"] getUUIDBytes:bytes];
    uint8_t *cursor=(uint8_t *)(header+1);
    for(uint32_t i=0;i<count;i++) {
        struct uuid_command command={0}; command.cmd=LC_UUID; command.cmdsize=(invalidCommand&&i==0)?sizeof(command)-1:sizeof(command);
        memcpy(command.uuid,bytes,16); memcpy(cursor,&command,sizeof(command)); cursor+=sizeof(command);
    }
    return data;
}

int main(void) {
    @autoreleasepool {
        NSData *mainImage=timantirecall_imageHeader(MH_EXECUTE,CPU_TYPE_ARM64,CPU_SUBTYPE_ARM64_ALL,NO,NO);
        NSString *mainUUID=timantirecall_uuidForMainExecutableHeader((const struct mach_header *)mainImage.bytes);
        CHECK([mainUUID isEqualToString:@"3C237FA0-5985-3376-BF98-EF1698563247"]);
        NSData *image0Dylib=timantirecall_imageHeader(MH_DYLIB,CPU_TYPE_ARM64,CPU_SUBTYPE_ARM64_ALL,NO,NO);
        CHECK(timantirecall_uuidForMainExecutableHeader((const struct mach_header *)image0Dylib.bytes)==nil);
        NSData *wrongCPU=timantirecall_imageHeader(MH_EXECUTE,CPU_TYPE_ARM64,CPU_SUBTYPE_ARM64E,NO,NO);
        CHECK(timantirecall_uuidForMainExecutableHeader((const struct mach_header *)wrongCPU.bytes)==nil);
        NSData *duplicate=timantirecall_imageHeader(MH_EXECUTE,CPU_TYPE_ARM64,CPU_SUBTYPE_ARM64_ALL,YES,NO);
        CHECK(timantirecall_uuidForMainExecutableHeader((const struct mach_header *)duplicate.bytes)==nil);
        NSData *malformed=timantirecall_imageHeader(MH_EXECUTE,CPU_TYPE_ARM64,CPU_SUBTYPE_ARM64_ALL,NO,YES);
        CHECK(timantirecall_uuidForMainExecutableHeader((const struct mach_header *)malformed.bytes)==nil);
        NSString *temporary=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *testHome=[temporary stringByAppendingPathComponent:@"home"];
        NSString *testTmp=[temporary stringByAppendingPathComponent:@"tmp"];
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:testHome withIntermediateDirectories:YES attributes:nil error:NULL]);
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:testTmp withIntermediateDirectories:YES attributes:nil error:NULL]);
        CHECK(setenv("HOME",testHome.fileSystemRepresentation,1)==0);
        CHECK(setenv("TMPDIR",testTmp.fileSystemRepresentation,1)==0);
        CHECK(setenv("TIMANTIRECALL_TEST_STATE_DIR",testTmp.fileSystemRepresentation,1)==0);
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
        timantirecall_installSessionTracking(TIMAntiRecallTestTarget.class);
        OCInitSessionConfig *config=[OCInitSessionConfig new];config.selfUid=@"u_two";
        NSObject *depends=NSObject.new,*dispatcher=NSObject.new,*listener=NSObject.new;
        [target init:config depends:depends dispatcherDepends:dispatcher listener:listener];
        CHECK(timantirecall_initCalls==1 && [timantirecall_sessionOwner(target) isEqual:@"u_two"]);
        CHECK(timantirecall_sessionArguments[0]==config && timantirecall_sessionArguments[1]==depends &&
              timantirecall_sessionArguments[2]==dispatcher && timantirecall_sessionArguments[3]==listener);
        config.selfUid=@"changed_uid";
        CHECK([timantirecall_sessionOwner(target) isEqual:@"u_two"]);
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
        NSData *recallList=timantirecall_bytes(11,timantirecall_join(@[timantirecall_bytes(1,[@"third_actor" dataUsingEncoding:4]),timantirecall_bytes(3,timantirecall_int(1,42))]));
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
        timantirecall_testOwnRecall(target,command,extra);
        CHECK([timantirecall_sharedMarks() timantirecall_flush:NULL]);
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
