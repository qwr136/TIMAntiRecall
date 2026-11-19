#import <Foundation/Foundation.h>
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallStorage.h"
#import "TIMAntiRecallWire.h"
#include <stdlib.h>
static unsigned timantirecall_checks;
@interface QQAccountsManager:NSObject
@property(nonatomic,copy) NSString *currentUid;
+ (instancetype)GetInstance;
@end
@implementation QQAccountsManager
+ (instancetype)GetInstance {
    static QQAccountsManager *manager;static dispatch_once_t once;
    dispatch_once(&once,^{manager=[self new];});return manager;
}
@end
#define CHECK(...) do{timantirecall_checks++;if(!(__VA_ARGS__)){NSLog(@"FAIL state line%d %s",__LINE__,#__VA_ARGS__);exit(1);}}while(0)
static NSData *timantirecall_var(uint64_t n){NSMutableData *d=[NSMutableData data];do{uint8_t b=n&127;n>>=7;if(n)b|=128;[d appendBytes:&b length:1];}while(n);return d;}
static NSData *timantirecall_int(unsigned f,uint64_t n){NSMutableData *d=[timantirecall_var((uint64_t)f<<3) mutableCopy];[d appendData:timantirecall_var(n)];return d;}
static NSData *timantirecall_blob(unsigned f,NSData *v){NSMutableData *d=[timantirecall_var(((uint64_t)f<<3)|2) mutableCopy];[d appendData:timantirecall_var(v.length)];[d appendData:v];return d;}
static NSData *timantirecall_join(NSArray *a){NSMutableData *d=[NSMutableData data];for(NSData *v in a)[d appendData:v];return d;}
static NSData *timantirecall_packet(BOOL group,BOOL author){
    NSData *content;
    if(group){
        NSData *message=timantirecall_int(1,42);
        if(author)message=timantirecall_join(@[message,timantirecall_blob(6,[@"member" dataUsingEncoding:4])]);
        NSData *notify=timantirecall_join(@[timantirecall_int(1,7),timantirecall_int(4,99),timantirecall_blob(11,timantirecall_blob(3,message))]);
        uint8_t prefix[]={0,0,0,99,0,(uint8_t)(notify.length>>8),(uint8_t)notify.length};
        content=timantirecall_join(@[[NSData dataWithBytes:prefix length:7],notify]);
    }else content=timantirecall_blob(1,timantirecall_join(@[timantirecall_blob(1,[@"peer" dataUsingEncoding:4]),timantirecall_blob(2,[@"owner" dataUsingEncoding:4]),timantirecall_int(20,42)]));
    NSData *head=timantirecall_join(@[timantirecall_int(1,group?732:528),timantirecall_int(2,group?17:138)]);
    return timantirecall_blob(1,timantirecall_join(@[timantirecall_blob(2,head),timantirecall_blob(3,timantirecall_blob(2,content))]));
}
static NSDictionary *timantirecall_private(void){return @{@"owner":@"owner",@"kind":@1,@"seq":@42,@"id":@9001,@"random":@123,@"time":@1700000000,@"peer":@"peer",@"from":@"peer",@"to":@"owner",@"author":@"peer",@"text":@"NEVER-SAVE-CONTENT"};}
static NSDictionary *timantirecall_group(void){return @{@"owner":@"owner",@"kind":@2,@"seq":@43,@"id":@9002,@"group":@99,@"author":@"member",@"random":@33,@"time":@1700000000};}
int main(int argc,const char **argv){@autoreleasepool {
    CHECK(argc==2);NSString *mode=@(argv[1]);NSError *error=nil;
    NSURL *settingsURL=timantirecall_stateURL(@"preferences.plist"),*marksURL=timantirecall_stateURL(@"marks.plist");
    TIMAntiRecallSettings *settings=[[TIMAntiRecallSettings alloc] initWithURL:settingsURL];
    TIMAntiRecallMarkStore *store=[[TIMAntiRecallMarkStore alloc] initWithURL:marksURL persistent:YES];
    QQAccountsManager.GetInstance.currentUid=@"owner";
    if([mode isEqual:@"seed"]){
        CHECK([settings timantirecall_enabled] && [settings timantirecall_persistMarks] && ![settings timantirecall_showTime]);
        CHECK(![settings timantirecall_autoClaimRedPackets] && ![settings timantirecall_packetDiagnostics] && ![settings timantirecall_claimOwnRedPackets]);
        CHECK(![NSFileManager.defaultManager fileExistsAtPath:settingsURL.path]);
        CHECK([settings timantirecall_setPacketOption:@"diagnostics" enabled:YES owner:@"owner" error:&error]);
        CHECK([settings timantirecall_packetDiagnostics] && ![settings timantirecall_autoClaimRedPackets]);
        CHECK([settings timantirecall_setPacketOption:@"autoClaim" enabled:YES owner:@"owner" error:&error]);
        CHECK([settings timantirecall_autoClaimRedPackets]);
        CHECK([settings timantirecall_setPacketOption:@"claimOwn" enabled:YES owner:@"owner" error:&error]);
        CHECK([settings timantirecall_claimOwnRedPackets]);
        CHECK([settings timantirecall_setChat:timantirecall_private() enabled:NO error:&error]);CHECK(!error);
        CHECK(![settings timantirecall_shouldBlockData:timantirecall_packet(NO,YES) owner:@"owner"]);
        CHECK([settings timantirecall_shouldBlockData:timantirecall_packet(NO,YES) owner:@"other"]);
        CHECK([settings timantirecall_shouldBlockData:timantirecall_packet(YES,NO) owner:@"owner"]);
        CHECK([settings timantirecall_setChat:timantirecall_group() enabled:NO error:&error]);
        CHECK(![settings timantirecall_shouldBlockData:timantirecall_packet(YES,NO) owner:@"owner"]);
        CHECK(![settings timantirecall_shouldBlockData:timantirecall_packet(YES,YES) owner:@"owner"]);
        CHECK([settings timantirecall_shouldBlockData:timantirecall_packet(YES,YES) owner:@"other"]);
        CHECK([settings timantirecall_updateOptions:@{@"showTime":@YES} error:&error]);
        CHECK(![settings timantirecall_updateOptions:@{@"enabled":@"yes"} error:&error]);
        CHECK([settings timantirecall_enabled]);
        [store timantirecall_addEvents:@[timantirecall_private(),timantirecall_group()] owner:@"owner"];
        CHECK([store timantirecall_flush:&error]);CHECK(!error);
        NSDictionary *before=[store timantirecall_eventForIdentity:timantirecall_private()];CHECK(before);
        [store timantirecall_addEvents:@[timantirecall_private()] owner:@"owner"];
        CHECK([[store timantirecall_eventForIdentity:timantirecall_private()][@"capturedAt"] isEqual:before[@"capturedAt"]]);
        CHECK([store timantirecall_eventsForOwner:@"owner"].count==2);
        CHECK([store timantirecall_eventsForOwner:@"other"].count==0);
        NSDictionary *saved=timantirecall_readState(marksURL,&error);
        CHECK([saved[@"events"] count]==2);
        for(NSDictionary *event in saved[@"events"])CHECK(!event[@"text"] && !event[@"image"] && !event[@"content"]);
        CHECK(timantirecall_writeState(@{@"first":before[@"capturedAt"]},timantirecall_stateURL(@"expected.plist"),&error));
        NSLog(@"PASS %u state seed checks; separate process restore required",timantirecall_checks);return 0;
    }
    if([mode isEqual:@"restore"]){
        CHECK(![settings timantirecall_lastError] && ![store timantirecall_lastError]);
        CHECK([settings timantirecall_autoClaimRedPackets] && [settings timantirecall_packetDiagnostics] && [settings timantirecall_claimOwnRedPackets]);
        QQAccountsManager.GetInstance.currentUid=@"other";
        CHECK(![settings timantirecall_autoClaimRedPackets] && ![settings timantirecall_packetDiagnostics] && ![settings timantirecall_claimOwnRedPackets]);
        CHECK(![settings timantirecall_setPacketOption:@"autoClaim" enabled:NO owner:@"owner" error:&error]);
        QQAccountsManager.GetInstance.currentUid=@"owner";
        CHECK([settings timantirecall_autoClaimRedPackets]);
        CHECK([settings timantirecall_showTime]);CHECK(![settings timantirecall_enabledForChat:timantirecall_private()]);
        CHECK(![settings timantirecall_shouldBlockData:timantirecall_packet(NO,YES) owner:@"owner"]);
        CHECK(![settings timantirecall_shouldBlockData:timantirecall_packet(YES,NO) owner:@"owner"]);
        CHECK([store timantirecall_containsIdentity:timantirecall_private()]);CHECK([store timantirecall_containsIdentity:timantirecall_group()]);
        NSDictionary *expected=timantirecall_readState(timantirecall_stateURL(@"expected.plist"),&error);
        CHECK([[store timantirecall_eventForIdentity:timantirecall_private()][@"capturedAt"] isEqual:expected[@"first"]]);
        NSMutableDictionary *wrong=[timantirecall_private() mutableCopy];wrong[@"owner"]=@"other";CHECK(![store timantirecall_containsIdentity:wrong]);
        [settings timantirecall_observeChat:@{@"kind":@1,@"peer":@"peer",@"owner":@"owner",@"peerUin":@123456}];
        CHECK([settings timantirecall_chatForAlias:@"123456" kind:1 owner:@"owner"]);
        CHECK(![settings timantirecall_chatForAlias:@"123456" kind:1 owner:@"other"]);
        [settings timantirecall_observeChat:@{@"kind":@1,@"peer":@"other_peer",@"owner":@"owner",@"peerUin":@123456}];
        CHECK(![settings timantirecall_chatForAlias:@"123456" kind:1 owner:@"owner"]);
        [store timantirecall_setPersistent:NO];CHECK([store timantirecall_flush:&error]);
        CHECK(![NSFileManager.defaultManager fileExistsAtPath:marksURL.path]);
        CHECK([store timantirecall_containsIdentity:timantirecall_private()]);
        TIMAntiRecallMarkStore *empty=[[TIMAntiRecallMarkStore alloc] initWithURL:marksURL persistent:NO];
        CHECK(![empty timantirecall_containsIdentity:timantirecall_private()]);
        [store timantirecall_setPersistent:YES];CHECK([store timantirecall_flush:&error]);
        TIMAntiRecallMarkStore *reloaded=[[TIMAntiRecallMarkStore alloc] initWithURL:marksURL persistent:YES];
        CHECK([reloaded timantirecall_containsIdentity:timantirecall_private()]);
        CHECK([settings timantirecall_updateOptions:@{@"enabled":@NO} error:&error]);
        CHECK(![settings timantirecall_shouldBlockData:timantirecall_packet(YES,YES) owner:@"other"]);
        CHECK([settings timantirecall_updateOptions:@{@"enabled":@YES} error:&error]);
        CHECK([settings timantirecall_shouldBlockData:timantirecall_packet(YES,YES) owner:@"other"]);
        NSLog(@"PASS %u separate-process restore/settings/first-time/account checks",timantirecall_checks);return 0;
    }
    CHECK([mode isEqual:@"negative"]);
    NSURL *broken=timantirecall_stateURL(@"broken.plist");
    CHECK([@"not-a-plist" writeToURL:broken atomically:YES encoding:NSUTF8StringEncoding error:&error]);
    NSData *original=[NSData dataWithContentsOfURL:broken];
    TIMAntiRecallSettings *bad=[[TIMAntiRecallSettings alloc] initWithURL:broken];CHECK([bad timantirecall_lastError]);
    CHECK(![bad timantirecall_updateOptions:@{@"enabled":@NO} error:&error]);
    CHECK([[NSData dataWithContentsOfURL:broken] isEqual:original]);
    TIMAntiRecallMarkStore *badMarks=[[TIMAntiRecallMarkStore alloc] initWithURL:broken persistent:YES];
    CHECK([badMarks timantirecall_lastError]);[badMarks timantirecall_addEvents:@[timantirecall_private()] owner:@"owner"];
    CHECK(![badMarks timantirecall_flush:&error]);CHECK([[NSData dataWithContentsOfURL:broken] isEqual:original]);
    NSURL *malformed=timantirecall_stateURL(@"malformed.plist");
    CHECK(timantirecall_writeState(@{@"schema":@1,@"enabled":@"YES"},malformed,&error));
    CHECK([[[TIMAntiRecallSettings alloc] initWithURL:malformed] timantirecall_lastError]);
    CHECK(timantirecall_writeState(@{@"schema":@1,@"events":@[@{@"owner":@"owner",@"kind":@1,@"capturedAt":@1}]},malformed,&error));
    CHECK([[[TIMAntiRecallMarkStore alloc] initWithURL:malformed persistent:YES] timantirecall_lastError]);
    NSURL *link=timantirecall_stateURL(@"link.plist");
    CHECK([NSFileManager.defaultManager createSymbolicLinkAtPath:link.path withDestinationPath:broken.path error:&error]);
    CHECK(!timantirecall_writeState(@{@"schema":@1},link,&error));
    CHECK([[NSData dataWithContentsOfURL:broken] isEqual:original]);
    CHECK(![settings timantirecall_setChat:(id)@"bad" enabled:NO error:&error]);
    CHECK(![settings timantirecall_setChat:@{@"owner":@"other",@"kind":@2,@"group":@0} enabled:NO error:&error]);
    TIMAntiRecallMarkStore *memory=[TIMAntiRecallMarkStore new];
    for(unsigned i=1;i<=4097;i++)[memory timantirecall_addEvents:@[@{@"kind":@2,@"group":@99,@"seq":@(i),@"author":@"member"}] owner:@"owner"];
    CHECK([memory timantirecall_eventsForOwner:@"owner"].count==4096);
    CHECK(![memory timantirecall_containsIdentity:@{@"owner":@"owner",@"kind":@2,@"group":@99,@"seq":@1,@"author":@"member"}]);
    NSLog(@"PASS %u corrupted-file/symlink/bounds checks",timantirecall_checks);
    return 0;
}}
