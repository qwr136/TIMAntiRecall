#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallStorage.h"
#include <math.h>
#include <string.h>
static BOOL timantirecall_uintValue(id value,BOOL positive) {
    return [value isKindOfClass:NSNumber.class] && !strchr([value objCType],'d') &&
        !strchr([value objCType],'f') && [value longLongValue]>=(positive?1:0);
}
// The wire sequence selects a candidate; it is not the full record identity.
// Pin the first accepted record's id/random/time, without storing its contents.
static NSDictionary *timantirecall_recordBinding(NSDictionary *identity) {
    if(![identity isKindOfClass:NSDictionary.class])return nil;
    NSMutableDictionary *binding=[NSMutableDictionary dictionary];
    for(NSString *key in @[@"id",@"random",@"time"]) {
        id value=identity[key];
        if(![value isKindOfClass:NSNumber.class] || strchr([value objCType],'d') ||
           strchr([value objCType],'f') || (CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID()))return nil;
        binding[key]=@([value longLongValue]);
    }
    if(![binding[@"id"] longLongValue])return nil;
    return [binding copy];
}
static NSDictionary *timantirecall_normalizedMark(NSDictionary *input,NSString *owner,NSTimeInterval captured) {
    if(![input isKindOfClass:NSDictionary.class]||!timantirecall_validUID(owner)||
       !timantirecall_uintValue(input[@"seq"],YES)||!isfinite(captured)||captured<=0||captured>4102444800.0)return nil;
    NSMutableDictionary *e=[@{@"owner":[owner copy],@"seq":input[@"seq"],@"capturedAt":@(captured)} mutableCopy];
    if([input[@"kind"] isEqual:@1]) {
        NSString *from=input[@"from"],*to=input[@"to"];
        if(!timantirecall_validUID(from)||!timantirecall_validUID(to))return nil;
        NSString *peer=[from isEqual:owner]?to:[to isEqual:owner]?from:nil;
        if(!peer)return nil;
        e[@"kind"]=@1;e[@"from"]=[from copy];e[@"to"]=[to copy];e[@"author"]=[from copy];e[@"peer"]=[peer copy];
    }else if([input[@"kind"] isEqual:@2] && timantirecall_uintValue(input[@"group"],YES) && timantirecall_validUID(input[@"author"])) {
        e[@"kind"]=@2;e[@"group"]=input[@"group"];e[@"author"]=[input[@"author"] copy];
        for(NSString *key in @[@"random",@"time"]) {
            if(input[key] && !timantirecall_uintValue(input[key],NO))return nil;
            if(input[key])e[key]=input[key];
        }
    }else return nil;
    if(input[@"binding"]) {
        NSDictionary *binding=timantirecall_recordBinding(input[@"binding"]);
        if(!binding)return nil;
        e[@"binding"]=binding;
    }
    if([input[@"displayAmbiguous"] isEqual:@YES])e[@"displayAmbiguous"]=@YES;
    return [e copy];
}
static NSDictionary *timantirecall_markKey(NSDictionary *event) {
    NSMutableDictionary *key=[event mutableCopy];
    [key removeObjectsForKeys:@[@"capturedAt",@"binding",@"displayAmbiguous"]];
    return [key copy];
}
BOOL timantirecall_recallEventMatchesIdentity(NSDictionary *event,NSDictionary *identity) {
    if(![event isKindOfClass:NSDictionary.class]||![identity isKindOfClass:NSDictionary.class])return NO;
    if(![event[@"owner"] isEqual:identity[@"owner"]]||![event[@"kind"] isEqual:identity[@"kind"]]||
       ![event[@"seq"] isEqual:identity[@"seq"]]||![event[@"author"] isEqual:identity[@"author"]])return NO;
    NSString *scope=[event[@"kind"] intValue]==1?@"peer":@"group";
    if(![event[scope] isEqual:identity[scope]])return NO;
    if(event[@"random"] && ![event[@"random"] isEqual:identity[@"random"]])return NO;
    if(event[@"time"] && ![event[@"time"] isEqual:identity[@"time"]])return NO;
    return YES;
}
@interface TIMAntiRecallMarkStore ()
@property(nonatomic,strong) NSMutableSet<NSDictionary *> *timantirecall_keys;
@property(nonatomic,strong) NSMutableArray<NSDictionary *> *timantirecall_events;
@property(nonatomic,strong) NSURL *timantirecall_url;
@property(nonatomic,strong) dispatch_queue_t timantirecall_io;
@property(nonatomic) BOOL timantirecall_persistent;
@property(nonatomic) BOOL timantirecall_writeQueued;
@property(nonatomic) NSUInteger timantirecall_generation;
@property(nonatomic,strong) NSError *timantirecall_error;
@end
@implementation TIMAntiRecallMarkStore
- (instancetype)init {
    self=[super init];if(self){_timantirecall_events=[NSMutableArray array];_timantirecall_keys=[NSMutableSet set];_timantirecall_io=dispatch_queue_create("com.minis.timantirecall.marks-io",DISPATCH_QUEUE_SERIAL);}return self;
}
- (instancetype)initWithURL:(NSURL *)url persistent:(BOOL)persistent {
    self=[self init];if(!self)return nil;
    _timantirecall_url=url;_timantirecall_persistent=persistent;
    if(!persistent)return self;
    NSError *error=nil;NSDictionary *state=timantirecall_readState(url,&error);
    if(state) {
        id events=state[@"events"];
        if(![state[@"schema"] isEqual:@1]||![events isKindOfClass:NSArray.class]||[events count]>4096)
            error=timantirecall_storageError(@"撤回标记文件格式异常，未覆盖原文件");
        if(!error)for(id event in events) {
            if(![event isKindOfClass:NSDictionary.class]||![event[@"capturedAt"] isKindOfClass:NSNumber.class]){error=timantirecall_storageError(@"撤回标记条目异常");break;}
            NSDictionary *normal=timantirecall_normalizedMark(event,event[@"owner"],[event[@"capturedAt"] doubleValue]);
            if(!normal){error=timantirecall_storageError(@"撤回标记身份异常");break;}
            [_timantirecall_events addObject:normal];
        }
    }
    if(error){[_timantirecall_events removeAllObjects];[_timantirecall_keys removeAllObjects];}
    else for(NSDictionary *mark in _timantirecall_events)[_timantirecall_keys addObject:timantirecall_markKey(mark)];
    _timantirecall_error=error;return self;
}
- (void)timantirecall_notify {
    dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:TIMAntiRecallStateChangedNotification object:self];});
}
- (void)timantirecall_scheduleWrite {
    @synchronized(self) {
        if(!self.timantirecall_url || (self.timantirecall_persistent && self.timantirecall_error))return;
        self.timantirecall_generation++;
        if(self.timantirecall_writeQueued)return;
        self.timantirecall_writeQueued=YES;
        dispatch_async(self.timantirecall_io,^{
            NSUInteger generation;BOOL persistent;NSDictionary *state;
            @synchronized(self){
                generation=self.timantirecall_generation;persistent=self.timantirecall_persistent;
                state=@{@"schema":@1,@"events":[self.timantirecall_events copy]};
            }
            NSError *error=nil;
            if(persistent)timantirecall_writeState(state,self.timantirecall_url,&error);
            else timantirecall_removeState(self.timantirecall_url,&error);
            @synchronized(self){
                self.timantirecall_error=error;self.timantirecall_writeQueued=NO;
                if(generation!=self.timantirecall_generation && (!error || !self.timantirecall_persistent))
                    [self timantirecall_scheduleWrite];
            }
            if(error)[self timantirecall_notify];
        });
    }
}
- (void)timantirecall_setPersistent:(BOOL)persistent {
    @synchronized(self) {
        if(persistent==self.timantirecall_persistent)return;
        self.timantirecall_persistent=persistent;[self timantirecall_scheduleWrite];
    }
}
- (NSError *)timantirecall_lastError {@synchronized(self){return self.timantirecall_error;}}
- (BOOL)timantirecall_flush:(NSError **)error {
    for(unsigned attempt=0;attempt<8;attempt++) {
        dispatch_sync(self.timantirecall_io,^{});
        @synchronized(self){
            if(!self.timantirecall_writeQueued){if(error)*error=self.timantirecall_error;return !self.timantirecall_error;}
        }
    }
    if(error)*error=timantirecall_storageError(@"状态仍在写入，请稍后重试");return NO;
}
- (void)timantirecall_addEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner {
    [self timantirecall_addEvents:events owner:owner capturedAt:NSDate.date.timeIntervalSince1970];
}
- (void)timantirecall_addEvents:(NSArray<NSDictionary *> *)events owner:(NSString *)owner capturedAt:(NSTimeInterval)now {
    if(!timantirecall_validUID(owner)||![events isKindOfClass:NSArray.class])return;
    BOOL changed=NO;
    @synchronized(self) {
        for(NSDictionary *input in events) {
            NSDictionary *e=timantirecall_normalizedMark(input,owner,now);if(!e)continue;
            NSDictionary *key=timantirecall_markKey(e);
            if([self.timantirecall_keys containsObject:key])continue;
            [self.timantirecall_keys addObject:key];[self.timantirecall_events addObject:e];changed=YES;
            if(self.timantirecall_events.count>4096){
                [self.timantirecall_keys removeObject:timantirecall_markKey(self.timantirecall_events.firstObject)];
                [self.timantirecall_events removeObjectAtIndex:0];
            }
        }
        if(changed && self.timantirecall_persistent)[self timantirecall_scheduleWrite];
    }
}
- (NSDictionary *)timantirecall_displayCandidateForIdentity:(NSDictionary *)identity {
    if(!timantirecall_recordBinding(identity))return nil;
    @synchronized(self) {
        NSDictionary *match=nil;
        for(NSDictionary *event in self.timantirecall_events) {
            if(!timantirecall_recallEventMatchesIdentity(event,identity))continue;
            if(match || [event[@"displayAmbiguous"] boolValue])return nil;
            match=event;
        }
        return match;
    }
}
- (void)timantirecall_suppressDisplayForEvent:(NSDictionary *)event {
    NSDictionary *key=timantirecall_markKey(event);
    @synchronized(self) {
        if(![self.timantirecall_keys containsObject:key])return;
        for(NSUInteger i=0;i<self.timantirecall_events.count;i++) {
            NSDictionary *stored=self.timantirecall_events[i];
            if(![timantirecall_markKey(stored) isEqual:key])continue;
            if([stored[@"displayAmbiguous"] boolValue])return;
            NSMutableDictionary *updated=stored.mutableCopy;
            updated[@"displayAmbiguous"]=@YES;
            self.timantirecall_events[i]=updated.copy;
            if(self.timantirecall_persistent)[self timantirecall_scheduleWrite];
            return;
        }
    }
}
- (NSDictionary *)timantirecall_eventForIdentity:(NSDictionary *)identity {
    if(![identity isKindOfClass:NSDictionary.class])return nil;
    @synchronized(self) {
        for(NSUInteger index=self.timantirecall_events.count;index>0;index--) {
            NSDictionary *event=self.timantirecall_events[index-1];
            if(!timantirecall_recallEventMatchesIdentity(event,identity))continue;
            if([event[@"displayAmbiguous"] boolValue])return nil;
            NSDictionary *binding=timantirecall_recordBinding(identity);
            if(!binding)return nil;
            if(event[@"binding"]) {
                if(![event[@"binding"] isEqual:binding])continue;
            }else {
                NSMutableDictionary *pinned=event.mutableCopy;
                pinned[@"binding"]=binding;
                event=pinned.copy;
                self.timantirecall_events[index-1]=event;
                if(self.timantirecall_persistent)[self timantirecall_scheduleWrite];
            }
            return event;
        }
    }
    return nil;
}
- (BOOL)timantirecall_containsIdentity:(NSDictionary *)identity {
    if(![identity isKindOfClass:NSDictionary.class])return NO;
    NSDictionary *binding=timantirecall_recordBinding(identity);
    if(!binding)return NO;
    @synchronized(self) {
        for(NSUInteger index=self.timantirecall_events.count;index>0;index--) {
            NSDictionary *event=self.timantirecall_events[index-1];
            if(!timantirecall_recallEventMatchesIdentity(event,identity))continue;
            NSDictionary *stored=event[@"binding"];
            // Display ambiguity suppresses only the red frame. Cold-sync
            // protection remains valid when this exact message was already pinned.
            if(stored)return [stored isEqual:binding];
            if([event[@"displayAmbiguous"] boolValue])return NO;
            NSMutableDictionary *pinned=event.mutableCopy;pinned[@"binding"]=binding;
            self.timantirecall_events[index-1]=pinned.copy;
            if(self.timantirecall_persistent)[self timantirecall_scheduleWrite];
            return YES;
        }
    }
    return NO;
}
- (NSArray<NSDictionary *> *)timantirecall_eventsForOwner:(NSString *)owner {
    @synchronized(self){
        NSMutableArray *result=[NSMutableArray array];
        for(NSDictionary *e in self.timantirecall_events.reverseObjectEnumerator)
            if([e[@"owner"] isEqual:owner])[result addObject:e];
        return [result copy];
    }
}
- (void)timantirecall_clear {
    @synchronized(self){
        [self.timantirecall_events removeAllObjects];[self.timantirecall_keys removeAllObjects];
        self.timantirecall_error=nil;[self timantirecall_scheduleWrite];
    }
    [self timantirecall_notify];
}
@end
TIMAntiRecallMarkStore *timantirecall_sharedMarks(void) {
    static TIMAntiRecallMarkStore *store;static dispatch_once_t once;
    dispatch_once(&once,^{store=[[TIMAntiRecallMarkStore alloc] initWithURL:timantirecall_stateURL(@"marks.plist") persistent:[timantirecall_settings() timantirecall_persistMarks]];});
    return store;
}
void timantirecall_prepareState(void) {
    (void)timantirecall_settings();(void)timantirecall_sharedMarks();
}
