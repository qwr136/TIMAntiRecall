#import "TIMAntiRecallRules.h"
#import "TIMAntiRecallMarks.h"
#import "TIMAntiRecallSettings.h"
#include <math.h>

static IMP timantirecall_textGetter(id object, const char *name, const char *type) {
    if (!object) return NULL;
    const char *args[] = {"@", ":"};
    Method method = class_getInstanceMethod(object_getClass(object), sel_registerName(name));
    return timantirecall_methodTypes(method, type, 2, args) ? method_getImplementation(method) : NULL;
}
static id timantirecall_textObject(id object, const char *name) {
    IMP getter = timantirecall_textGetter(object, name, "@");
    return getter ? ((id (*)(id, SEL))getter)(object, sel_registerName(name)) : nil;
}
static BOOL timantirecall_textKind(id object, const char *name, int *value) {
    IMP getter = timantirecall_textGetter(object, name, "i");
    if (!getter) return NO;
    *value = ((int (*)(id, SEL))getter)(object, sel_registerName(name));
    return YES;
}
NSString *timantirecall_plainRecordText(id record, NSString *owner, BOOL *mentioned) {
    if (mentioned) *mentioned = NO;
    Class recordClass = objc_getClass("OCMsgRecord"), elementClass = objc_getClass("OCMsgElement");
    Class textClass = objc_getClass("OCTextElement");
    if (!recordClass || !elementClass || !textClass || ![record isKindOfClass:recordClass]) return nil;
    id elements = timantirecall_textObject(record, "elements");
    if (![elements isKindOfClass:NSArray.class] || ![elements count] || [elements count] > 64) return nil;
    NSMutableString *body = [NSMutableString string];
    BOOL atSelf = NO;
    for (id element in elements) {
        int type;
        if (![element isKindOfClass:elementClass] || !timantirecall_textKind(element, "elementType", &type) || type != 1) return nil;
        id text = timantirecall_textObject(element, "textElement");
        if (![text isKindOfClass:textClass]) return nil;
        NSString *content = timantirecall_textObject(text, "content");
        if (![content isKindOfClass:NSString.class] || content.length > 65536 - body.length) return nil;
        [body appendString:content];
        int at;
        if (mentioned && timantirecall_validUID(owner) && timantirecall_textKind(text, "atType", &at) && at > 0) {
            id target = timantirecall_textObject(text, "atNtUid");
            if ([target isKindOfClass:NSString.class] && [owner isEqualToString:target]) atSelf = YES;
        }
    }
    if (mentioned) *mentioned = atSelf;
    return body.length ? [body copy] : nil;
}

@implementation TIMAntiRecallReplyGate {
    NSMutableOrderedSet<NSArray *> *_timantirecall_seen;
    NSMutableDictionary<NSArray *, NSNumber *> *_timantirecall_next;
    NSMutableArray<NSNumber *> *_timantirecall_recent;
}
- (instancetype)init {
    if ((self = [super init])) {
        _timantirecall_seen = [NSMutableOrderedSet orderedSet];
        _timantirecall_next = [NSMutableDictionary dictionary];
        _timantirecall_recent = [NSMutableArray array];
    }
    return self;
}
- (BOOL)timantirecall_reserve:(NSDictionary *)identity cooldown:(NSTimeInterval)cooldown now:(NSTimeInterval)uptime {
    NSString *chat = timantirecall_ruleChatKey(identity);
    id owner = identity[@"owner"], author = identity[@"author"], seq = identity[@"seq"], messageID = identity[@"id"];
    if (!chat || !timantirecall_validUID(owner) || !timantirecall_validUID(author) || [owner isEqual:author] ||
        ![seq isKindOfClass:NSNumber.class] || [seq longLongValue] <= 0 ||
        ![messageID isKindOfClass:NSNumber.class] || ![messageID longLongValue] ||
        !isfinite(cooldown) || cooldown < 10 || cooldown > 86400 || !isfinite(uptime) || uptime < 0) return NO;
    NSArray *scope = @[owner, chat], *record = @[owner, chat, author, seq, messageID];
    @synchronized (self) {
        if ([_timantirecall_seen containsObject:record]) return NO;
        // Remember even a match suppressed by the cooldown. Replayed delivery must not trigger later.
        if (_timantirecall_seen.count >= 4096) [_timantirecall_seen removeObjectAtIndex:0];
        [_timantirecall_seen addObject:record];
        while (_timantirecall_recent.count && uptime - _timantirecall_recent.firstObject.doubleValue >= 60)
            [_timantirecall_recent removeObjectAtIndex:0];
        if (_timantirecall_recent.count >= 6 || (_timantirecall_recent.count && uptime - _timantirecall_recent.lastObject.doubleValue < 2)) return NO;
        if ([_timantirecall_next[scope] doubleValue] > uptime) return NO;
        if (_timantirecall_next.count >= 512) {
            for (NSArray *key in _timantirecall_next.allKeys)
                if (_timantirecall_next[key].doubleValue <= uptime) [_timantirecall_next removeObjectForKey:key];
            if (_timantirecall_next.count >= 512) return NO;
        }
        _timantirecall_next[scope] = @(uptime + cooldown);
        [_timantirecall_recent addObject:@(uptime)];
        return YES;
    }
}
@end
