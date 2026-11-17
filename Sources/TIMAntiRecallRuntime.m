#import "TIMAntiRecallRuntime.h"
#import "TIMAntiRecallWire.h"
#import <objc/message.h>
#import <stdatomic.h>
#import <string.h>

static _Atomic(IMP) timantirecall_originalPush = NULL;
static Class timantirecall_hookedClass = Nil;
static atomic_uint timantirecall_blocked = 0;

typedef void (*TIMAntiRecallPushIMP)(id, SEL, id, id, id);

BOOL timantirecall_matchesTarget(NSString *bundle, NSString *version, NSString *build,
                                 NSString *executable, NSString *uuid) {
    return [bundle isEqualToString:@"com.tencent.tim"] &&
           [version isEqualToString:@"4.1.0"] && [build isEqualToString:@"4.1.0.81"] &&
           [executable isEqualToString:@"QQ"] &&
           [uuid isKindOfClass:NSString.class] &&
           [uuid caseInsensitiveCompare:@"3C237FA0-5985-3376-BF98-EF1698563247"] == NSOrderedSame;
}

static void timantirecall_receivePush(id receiver, SEL selector, id command, id buffer, id extra) {
    TIMAntiRecallDecision decision = TIMAntiRecallPass;
    if ([command isKindOfClass:NSString.class] &&
        [command isEqualToString:@"trpc.msg.olpush.OlPushService.MsgPush"] &&
        [buffer isKindOfClass:NSData.class]) {
        NSData *data = buffer;
        // No cache or private getters. Unknown wire shapes reach TIM untouched.
        decision = timantirecall_classifyPush(data.bytes, data.length);
    }
    if (decision != TIMAntiRecallPass) {
        unsigned count = atomic_fetch_add_explicit(&timantirecall_blocked, 1, memory_order_relaxed);
        if (count < 32) timantirecall_logEvent(decision == TIMAntiRecallPrivate ?
            @"blocked-private-recall" : @"blocked-group-recall");
        return;
    }
    TIMAntiRecallPushIMP original = (TIMAntiRecallPushIMP)atomic_load_explicit(&timantirecall_originalPush, memory_order_acquire);
    if (original) original(receiver, selector, command, buffer, extra);
}

static BOOL timantirecall_validSignature(Method method) {
    if (!method || method_getNumberOfArguments(method) != 5) return NO;
    char type[16] = {0};
    method_getReturnType(method, type, sizeof(type));
    if (strcmp(type, "v") != 0) return NO;
    for (unsigned index = 0; index < 5; index++) {
        memset(type, 0, sizeof(type));
        method_getArgumentType(method, index, type, sizeof(type));
        const char *expected = index == 1 ? ":" : "@";
        if (strcmp(type, expected) != 0) return NO;
    }
    return YES;
}

BOOL timantirecall_installOnClass(Class target) {
    if (!target) return NO;
    @synchronized (NSObject.class) {
        if (timantirecall_hookedClass) return target == timantirecall_hookedClass;
        SEL selector = sel_registerName("onMsfPush:msgBuffer:pushExtraInfo:");
        unsigned count = 0; Method own = NULL;
        Method *methods = class_copyMethodList(target, &count);
        for (unsigned index = 0; index < count; index++) {
            if (method_getName(methods[index]) == selector) { own = methods[index]; break; }
        }
        free(methods);
        // Do not modify an inherited method or accept an ABI inferred from a name.
        if (!timantirecall_validSignature(own)) return NO;
        IMP current = method_getImplementation(own);
        if (!current || current == (IMP)timantirecall_receivePush) return NO;
        // Publication precedes method replacement. Installation runs once before
        // app launch; callers can always forward to an initialized original IMP.
        atomic_store_explicit(&timantirecall_originalPush, current, memory_order_release);
        method_setImplementation(own, (IMP)timantirecall_receivePush);
        timantirecall_hookedClass = target;
        return YES;
    }
}
