#import "TIMAntiRecallRules.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallStorage.h"
#import <objc/runtime.h>
#include <math.h>

static NSDictionary *timantirecall_ruleDefaults(void) {
    return @{ @"replyEnabled":@NO,@"replyKeywords":@[],@"replyText":@"",@"replyAllChats":@NO,
      @"replyChats":@[],@"onlyMention":@NO,@"quietEnabled":@NO,@"quietStart":@1320,@"quietEnd":@480,
      @"cooldown":@60,@"filterEnabled":@NO,@"filterKeywords":@[],@"filterAllChats":@NO,@"filterChats":@[] };
}
static BOOL timantirecall_ruleStrings(id value,NSUInteger count,NSUInteger length) {
    if(![value isKindOfClass:NSArray.class] || [value count]>count)return NO;
    for(id item in value)if(![item isKindOfClass:NSString.class] || ![item length] || [item length]>length)return NO;
    return YES;
}
static NSDictionary *timantirecall_normalPolicy(id input) {
    if(![input isKindOfClass:NSDictionary.class])return nil;
    NSMutableDictionary *policy=[timantirecall_ruleDefaults() mutableCopy];
    NSSet *flags=[NSSet setWithArray:@[@"replyEnabled",@"replyAllChats",@"onlyMention",@"quietEnabled",@"filterEnabled",@"filterAllChats"]];
    for(NSString *key in input) {
        id value=input[key];if(!policy[key])return nil;
        if([flags containsObject:key]) {if(![value isKindOfClass:NSNumber.class])return nil;policy[key]=@([value boolValue]);}
        else if([key isEqual:@"replyText"]) {if(![value isKindOfClass:NSString.class] || [value length]>1000)return nil;policy[key]=value;}
        else if([key hasSuffix:@"Keywords"] || [key hasSuffix:@"Chats"]) {
            BOOL chats=[key hasSuffix:@"Chats"];
            if(!timantirecall_ruleStrings(value,chats?256:64,chats?256:128))return nil;
            policy[key]=[[NSOrderedSet orderedSetWithArray:value] array];
        }else {
            if(![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue]))return nil;
            NSInteger number=[value integerValue];
            if([key isEqual:@"cooldown"] ? (number<10 || number>86400):(number<0 || number>1439))return nil;
            policy[key]=@(number);
        }
    }
    if([policy[@"replyEnabled"] boolValue] && (![policy[@"replyText"] length] || ![policy[@"replyKeywords"] count]))return nil;
    if([policy[@"filterEnabled"] boolValue] && ![policy[@"filterKeywords"] count])return nil;
    return [policy copy];
}
@interface TIMAntiRecallRules ()
@property(nonatomic,strong) NSURL *timantirecall_url;
@property(nonatomic,strong) NSMutableDictionary *timantirecall_owners;
@property(nonatomic,strong) NSError *timantirecall_readError;
@end
@implementation TIMAntiRecallRules
- (instancetype)initWithURL:(NSURL *)url {
    if((self=[super init])) {
        _timantirecall_url=url;_timantirecall_owners=[NSMutableDictionary dictionary];
        NSError *error=nil;id root=timantirecall_readState(url,&error);
        if(root) {
            if(![root isKindOfClass:NSDictionary.class] || ![root[@"version"] isEqual:@1] ||
               ![root[@"owners"] isKindOfClass:NSDictionary.class] || [root[@"owners"] count]>32)
                error=timantirecall_storageError(@"规则文件格式无效，未覆盖原文件");
            else for(NSString *owner in root[@"owners"]) {
                NSDictionary *policy=timantirecall_normalPolicy(root[@"owners"][owner]);
                if(!timantirecall_validUID(owner)||!policy) {error=timantirecall_storageError(@"规则文件内容无效，未覆盖原文件");break;}
                _timantirecall_owners[owner]=policy;
            }
        }
        if(error){[_timantirecall_owners removeAllObjects];_timantirecall_readError=error;}
    }return self;
}
- (NSDictionary *)timantirecall_policyForOwner:(NSString *)owner {
    @synchronized(self){return self.timantirecall_owners[owner?:@""]?:timantirecall_ruleDefaults();}
}
- (BOOL)timantirecall_savePolicy:(NSDictionary *)policy owner:(NSString *)owner error:(NSError **)error {
    NSDictionary *normalized=timantirecall_normalPolicy(policy);
    @synchronized(self) {
        NSError *failure=self.timantirecall_readError;
        if(!failure && (!timantirecall_validUID(owner)||!normalized))failure=timantirecall_storageError(@"规则无效：关键词每行一条，回复最长1000字，冷却10～86400秒");
        if(!failure && !self.timantirecall_owners[owner] && self.timantirecall_owners.count>=32)failure=timantirecall_storageError(@"账号规则已达上限");
        if(failure){if(error)*error=failure;return NO;}
        NSMutableDictionary *updated=[self.timantirecall_owners mutableCopy];updated[owner]=normalized;
        if(!timantirecall_writeState(@{@"version":@1,@"owners":updated},self.timantirecall_url,error))return NO;
        self.timantirecall_owners=updated;
    }
    dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:TIMAntiRecallSettingsChangedNotification object:self];});
    return YES;
}
@end
TIMAntiRecallRules *timantirecall_rules(void) {
    static TIMAntiRecallRules *rules;static dispatch_once_t once;
    dispatch_once(&once,^{rules=[[TIMAntiRecallRules alloc] initWithURL:timantirecall_stateURL(@"rules.plist")];});return rules;
}
NSString *timantirecall_ruleChatKey(NSDictionary *identity) {
    if(![identity isKindOfClass:NSDictionary.class])return nil;
    unsigned kind=[identity[@"kind"] unsignedIntValue];
    if(kind==1 && timantirecall_validUID(identity[@"peer"]))return [@"1:" stringByAppendingString:identity[@"peer"]];
    if(kind==2 && [identity[@"group"] isKindOfClass:NSNumber.class] && [identity[@"group"] longLongValue]>0)
        return [@"2:" stringByAppendingString:[identity[@"group"] stringValue]];
    return nil;
}
BOOL timantirecall_rulesMatchChat(NSDictionary *policy,NSDictionary *identity,BOOL reply) {
    NSString *key=timantirecall_ruleChatKey(identity);if(!key)return NO;
    return [policy[reply?@"replyAllChats":@"filterAllChats"] boolValue] || [policy[reply?@"replyChats":@"filterChats"] containsObject:key];
}
static BOOL timantirecall_ruleContains(NSArray *keywords,NSString *text) {
    if(![text isKindOfClass:NSString.class] || !text.length || text.length>65536)return NO;
    for(NSString *word in keywords)if(word.length && [text rangeOfString:word options:NSCaseInsensitiveSearch].location!=NSNotFound)return YES;
    return NO;
}
BOOL timantirecall_rulesHideText(NSDictionary *policy,NSString *text) {
    return [policy[@"filterEnabled"] boolValue] && timantirecall_ruleContains(policy[@"filterKeywords"],text);
}
NSString *timantirecall_rulesReply(NSDictionary *policy,NSDictionary *identity,NSString *text,BOOL mentioned,NSInteger minute) {
    if(![policy[@"replyEnabled"] boolValue] || !timantirecall_rulesMatchChat(policy,identity,YES) ||
       !timantirecall_validUID(identity[@"owner"]) || !timantirecall_validUID(identity[@"author"]) ||
       [identity[@"owner"] isEqual:identity[@"author"]] || ![identity[@"seq"] longLongValue] || ![identity[@"id"] longLongValue])return nil;
    if([policy[@"onlyMention"] boolValue] && !mentioned)return nil;
    if([policy[@"quietEnabled"] boolValue]) {
        NSInteger start=[policy[@"quietStart"] integerValue],end=[policy[@"quietEnd"] integerValue];
        if(minute<0 || minute>1439)return nil;
        if(start==end || (start<end ? (minute>=start && minute<end):(minute>=start || minute<end)))return nil;
    }
    NSString *reply=policy[@"replyText"];
    return reply.length && timantirecall_ruleContains(policy[@"replyKeywords"],text)?reply:nil;
}
