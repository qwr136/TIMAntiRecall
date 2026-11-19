#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallStorage.h"
#import "TIMAntiRecallWire.h"
#import <CoreFoundation/CoreFoundation.h>
#include <limits.h>
#include <string.h>
#include <stdlib.h>

NSNotificationName const TIMAntiRecallSettingsChangedNotification=@"com.minis.timantirecall.settings-changed";
NSNotificationName const TIMAntiRecallStateChangedNotification=@"com.minis.timantirecall.state-changed";
BOOL timantirecall_validUID(id value) {
    if(![value isKindOfClass:NSString.class]||![value length]||[value length]>128)return NO;
    static NSCharacterSet *bad;static dispatch_once_t once;
    dispatch_once(&once,^{bad=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet];});
    return [value rangeOfCharacterFromSet:bad].location==NSNotFound;
}
static BOOL timantirecall_boolean(id value) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID();
}
static BOOL timantirecall_groupNumber(id value) {
    return [value isKindOfClass:NSNumber.class] && [value longLongValue]>0 &&
        !strchr([value objCType],'f') && !strchr([value objCType],'d');
}
NSString *timantirecall_scopeKey(NSDictionary *identity) {
    if(![identity isKindOfClass:NSDictionary.class])return nil;
    id kind=identity[@"kind"];
    if(![kind isKindOfClass:NSNumber.class])return nil;
    if([kind intValue]==1 && timantirecall_validUID(identity[@"peer"]))
        return [@"p:" stringByAppendingString:identity[@"peer"]];
    if([kind intValue]==2 && timantirecall_groupNumber(identity[@"group"]))
        return [@"g:" stringByAppendingString:[identity[@"group"] stringValue]];
    return nil;
}
NSURL *timantirecall_stateURL(NSString *filename) {
    NSString *directory=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TIMAntiRecall"];
#ifdef TIMANTIRECALL_TESTING
    const char *test=getenv("TIMANTIRECALL_TEST_STATE_DIR");
    if(test && *test)directory=[NSString stringWithUTF8String:test];
#endif
    return [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:filename]];
}
static NSDictionary *timantirecall_chatIdentity(NSDictionary *input) {
    if(![input isKindOfClass:NSDictionary.class])return nil;
    NSString *scope=timantirecall_scopeKey(input);id owner=input[@"owner"];
    if(!scope||!timantirecall_validUID(owner))return nil;
    NSMutableDictionary *chat=[@{@"owner":[owner copy],@"kind":@([input[@"kind"] intValue])} mutableCopy];
    if([input[@"kind"] intValue]==1)chat[@"peer"]=[input[@"peer"] copy];
    else chat[@"group"]=input[@"group"];
    id alias=input[@"alias"];
    if(!alias && [input[@"peerUin"] isKindOfClass:NSNumber.class] && [input[@"peerUin"] longLongValue]>0)
        alias=[input[@"peerUin"] stringValue];
    if([alias isKindOfClass:NSString.class] && [alias length] && [alias length]<=128)chat[@"alias"]=[alias copy];
    return [chat copy];
}
static NSString *timantirecall_accountScope(NSDictionary *chat) {
    NSString *scope=timantirecall_scopeKey(chat);
    return scope && timantirecall_validUID(chat[@"owner"])?[NSString stringWithFormat:@"%@/%@",chat[@"owner"],scope]:nil;
}
@interface TIMAntiRecallSettings ()
@property(nonatomic,strong) NSURL *timantirecall_url;
@property(nonatomic,copy) NSDictionary *timantirecall_snapshot;
@property(nonatomic,copy) NSDictionary *timantirecall_overrides;
@property(nonatomic,strong) NSMutableDictionary *timantirecall_seen;
@property(nonatomic,strong) NSError *timantirecall_error;
@end
@implementation TIMAntiRecallSettings
- (instancetype)initWithURL:(NSURL *)url {
    self=[super init];if(!self)return nil;
    _timantirecall_url=url;_timantirecall_snapshot=@{};_timantirecall_overrides=@{};
    _timantirecall_seen=[NSMutableDictionary dictionary];
    NSError *error=nil;NSDictionary *state=timantirecall_readState(url,&error);
    if(state && ![self timantirecall_validate:state overrides:NULL])error=timantirecall_storageError(@"设置文件内容异常，未覆盖原文件");
    if(state && !error) {
        NSDictionary *overrides=nil;[self timantirecall_validate:state overrides:&overrides];
        _timantirecall_snapshot=[state copy];_timantirecall_overrides=overrides;
        for(NSDictionary *entry in state[@"chats"]) {
            NSDictionary *chat=timantirecall_chatIdentity(entry);_timantirecall_seen[timantirecall_accountScope(chat)]=chat;
        }
    }
    _timantirecall_error=error;return self;
}
- (BOOL)timantirecall_validate:(NSDictionary *)state overrides:(NSDictionary **)output {
    if(![state[@"schema"] isEqual:@1])return NO;
    for(NSString *key in @[@"enabled",@"persistMarks",@"showTime"])
        if(state[key] && !timantirecall_boolean(state[key]))return NO;
    id packetAccounts=state[@"packetAccounts"]?:@{};
    if(![packetAccounts isKindOfClass:NSDictionary.class] || [packetAccounts count]>64)return NO;
    for(id owner in packetAccounts) {
        id options=packetAccounts[owner];
        if(!timantirecall_validUID(owner) || ![options isKindOfClass:NSDictionary.class])return NO;
        for(id key in options)
            if(![@[@"autoClaim",@"diagnostics",@"claimOwn"] containsObject:key] || !timantirecall_boolean(options[key]))return NO;
    }
    id chats=state[@"chats"]?:@[];
    if(![chats isKindOfClass:NSArray.class]||[chats count]>1024)return NO;
    NSMutableDictionary *overrides=[NSMutableDictionary dictionary];
    for(id entry in chats) {
        if(![entry isKindOfClass:NSDictionary.class] || !timantirecall_boolean(entry[@"enabled"]))return NO;
        NSDictionary *chat=timantirecall_chatIdentity(entry);NSString *key=timantirecall_accountScope(chat);
        if(!key||overrides[key])return NO;
        overrides[key]=entry[@"enabled"];
    }
    if(output)*output=[overrides copy];return YES;
}
- (BOOL)timantirecall_enabled {@synchronized(self){return self.timantirecall_snapshot[@"enabled"]?[self.timantirecall_snapshot[@"enabled"] boolValue]:YES;}}
- (BOOL)timantirecall_persistMarks {@synchronized(self){return self.timantirecall_snapshot[@"persistMarks"]?[self.timantirecall_snapshot[@"persistMarks"] boolValue]:YES;}}
- (BOOL)timantirecall_showTime {@synchronized(self){return [self.timantirecall_snapshot[@"showTime"] boolValue];}}
- (BOOL)timantirecall_packetOption:(NSString *)key {
    NSString *owner=timantirecall_currentAccount();
    if(!timantirecall_validUID(owner))return NO;
    @synchronized(self) {
        return !self.timantirecall_error && [self.timantirecall_snapshot[@"packetAccounts"][owner][key] boolValue];
    }
}
- (BOOL)timantirecall_autoClaimRedPackets {return [self timantirecall_packetOption:@"autoClaim"];}
- (BOOL)timantirecall_claimOwnRedPackets {return [self timantirecall_packetOption:@"claimOwn"];}
- (BOOL)timantirecall_packetDiagnostics {return [self timantirecall_packetOption:@"diagnostics"];}
- (BOOL)timantirecall_setPacketOption:(NSString *)key enabled:(BOOL)enabled owner:(NSString *)owner error:(NSError **)error {
    if(!timantirecall_validUID(owner) || ![owner isEqual:timantirecall_currentAccount()] ||
       ![@[@"autoClaim",@"diagnostics",@"claimOwn"] containsObject:key]) {
        if(error)*error=timantirecall_storageError(@"账号已变化或设置项无效");return NO;
    }
    @synchronized(self) {
        NSMutableDictionary *state=self.timantirecall_snapshot.mutableCopy;
        NSMutableDictionary *accounts=[state[@"packetAccounts"] mutableCopy]?:[NSMutableDictionary dictionary];
        if(!accounts[owner] && accounts.count>=64) {
            if(error)*error=timantirecall_storageError(@"红包设置账号数量已达到64项上限");return NO;
        }
        NSMutableDictionary *options=[accounts[owner] mutableCopy]?:[NSMutableDictionary dictionary];
        options[key]=@(enabled);accounts[owner]=options.copy;
        state[@"schema"]=@1;state[@"packetAccounts"]=accounts.copy;
        return [self timantirecall_commit:state error:error];
    }
}
- (NSError *)timantirecall_lastError {@synchronized(self){return self.timantirecall_error;}}
- (BOOL)timantirecall_enabledForChat:(NSDictionary *)chat {
    NSString *key=timantirecall_accountScope(chat);
    @synchronized(self){return !key||!self.timantirecall_overrides[key]||[self.timantirecall_overrides[key] boolValue];}
}
- (BOOL)timantirecall_shouldBlockData:(NSData *)data owner:(NSString *)owner {
    if(![self timantirecall_enabled])return NO;
    @synchronized(self){if(!self.timantirecall_overrides.count)return YES;}
    if(!timantirecall_validUID(owner)||![data isKindOfClass:NSData.class])return YES;
    TIMAntiRecallWireEvent scope={0};
    if(!timantirecall_extractRecallScope(data.bytes,data.length,&scope))return YES;
    NSMutableDictionary *chat=[@{@"owner":owner,@"kind":@(scope.kind)} mutableCopy];
    if(scope.kind==2)chat[@"group"]=@(scope.group);
    else {
        NSString *from=@(scope.from),*to=@(scope.to);
        if([from isEqual:owner])chat[@"peer"]=to;
        else if([to isEqual:owner])chat[@"peer"]=from;
        else return YES;
    }
    return [self timantirecall_enabledForChat:chat];
}
- (BOOL)timantirecall_commit:(NSDictionary *)state error:(NSError **)error {
    NSDictionary *overrides=nil;
    if(self.timantirecall_error || ![self timantirecall_validate:state overrides:&overrides]) {
        if(error)*error=self.timantirecall_error?:timantirecall_storageError(@"设置内容无效");return NO;
    }
    NSError *failure=nil;
    if(!timantirecall_writeState(state,self.timantirecall_url,&failure)) {
        if(error)*error=failure;return NO;
    }
    self.timantirecall_snapshot=[state copy];self.timantirecall_overrides=overrides;
    dispatch_async(dispatch_get_main_queue(),^{
        [NSNotificationCenter.defaultCenter postNotificationName:TIMAntiRecallSettingsChangedNotification object:self];
    });
    return YES;
}
- (BOOL)timantirecall_updateOptions:(NSDictionary *)changes error:(NSError **)error {
    @synchronized(self) {
        if(![changes isKindOfClass:NSDictionary.class])return NO;
        NSMutableDictionary *state=[self.timantirecall_snapshot mutableCopy];state[@"schema"]=@1;
        for(id key in changes) {
            if(![@[@"enabled",@"persistMarks",@"showTime"] containsObject:key] || !timantirecall_boolean(changes[key])) {
                if(error)*error=timantirecall_storageError(@"设置项或类型无效");return NO;
            }
            state[key]=changes[key];
        }
        return [self timantirecall_commit:state error:error];
    }
}
- (BOOL)timantirecall_setChat:(NSDictionary *)input enabled:(BOOL)enabled error:(NSError **)error {
    NSDictionary *chat=timantirecall_chatIdentity(input);NSString *key=timantirecall_accountScope(chat);
    if(!key){if(error)*error=timantirecall_storageError(@"无法确认当前聊天身份，未修改");return NO;}
    @synchronized(self) {
        NSMutableDictionary *entry=[chat mutableCopy];entry[@"enabled"]=@(enabled);
        NSMutableArray *chats=[NSMutableArray array];
        for(NSDictionary *existing in self.timantirecall_snapshot[@"chats"])
            if(![timantirecall_accountScope(existing) isEqual:key])[chats addObject:existing];
        [chats addObject:entry];
        if(chats.count>1024){if(error)*error=timantirecall_storageError(@"独立聊天设置已达到1024项上限");return NO;}
        NSMutableDictionary *state=[self.timantirecall_snapshot mutableCopy];state[@"schema"]=@1;state[@"chats"]=[chats copy];
        if(![self timantirecall_commit:state error:error])return NO;
        self.timantirecall_seen[key]=chat;return YES;
    }
}
- (void)timantirecall_observeChat:(NSDictionary *)identity {
    NSDictionary *chat=timantirecall_chatIdentity(identity);NSString *key=timantirecall_accountScope(chat);
    if(!key)return;
    @synchronized(self) {
        NSDictionary *previous=self.timantirecall_seen[key];
        if(!chat[@"alias"] && previous[@"alias"])return;
        if([previous isEqual:chat])return;
        if(!previous && self.timantirecall_seen.count>=1024) {
            NSString *first=[[self.timantirecall_seen.allKeys sortedArrayUsingSelector:@selector(compare:)] firstObject];
            [self.timantirecall_seen removeObjectForKey:first];
        }
        self.timantirecall_seen[key]=chat;
    }
}
- (NSArray<NSDictionary *> *)timantirecall_chatsForOwner:(NSString *)owner {
    if(!timantirecall_validUID(owner))return @[];
    @synchronized(self) {
        NSMutableArray *result=[NSMutableArray array];
        for(NSDictionary *chat in self.timantirecall_seen.allValues)
            if([chat[@"owner"] isEqual:owner])[result addObject:chat];
        [result sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
            return [timantirecall_scopeKey(a) compare:timantirecall_scopeKey(b)];
        }];
        return [result copy];
    }
}
- (NSDictionary *)timantirecall_chatForAlias:(NSString *)alias kind:(unsigned)kind owner:(NSString *)owner {
    if(![alias isKindOfClass:NSString.class] || !alias.length || alias.length>128)return nil;
    NSDictionary *found=nil;
    for(NSDictionary *chat in [self timantirecall_chatsForOwner:owner]) {
        if([chat[@"kind"] unsignedIntValue]!=kind)continue;
        BOOL matches=[alias isEqual:chat[@"alias"]] || [alias isEqual:chat[@"peer"]] ||
                     (kind==2 && [alias isEqual:[chat[@"group"] stringValue]]);
        if(matches){if(found && ![timantirecall_scopeKey(found) isEqual:timantirecall_scopeKey(chat)])return nil;found=chat;}
    }
    return found;
}
@end
TIMAntiRecallSettings *timantirecall_settings(void) {
    static TIMAntiRecallSettings *settings;static dispatch_once_t once;
    dispatch_once(&once,^{settings=[[TIMAntiRecallSettings alloc] initWithURL:timantirecall_stateURL(@"preferences.plist")];});
    return settings;
}
BOOL timantirecall_shouldBlockRecall(NSData *data,NSString *owner) {
    return [timantirecall_settings() timantirecall_shouldBlockData:data owner:owner];
}
