#import "TIMAntiRecallReplayVideoFixture.h"
#import <objc/runtime.h>
@implementation OCVideoElement @end
@implementation TIMAntiRecallVideoForwardProbe
+ (instancetype)timantirecall_shared {
    static id shared;static dispatch_once_t once;
    dispatch_once(&once,^{
        Class native=objc_getClass("_TtC10MsgManager16MsgSenderHandler");
        if(!native) {native=objc_allocateClassPair(self,"_TtC10MsgManager16MsgSenderHandler",0);if(native)objc_registerClassPair(native);}
        shared=[[native alloc] init];
    });return shared;
}
- (void)forwardMsgWithMsgIds:(NSArray *)ids srcContact:(OCContact *)source dstContacts:(NSArray *)destinations msgAttributeInfos:(id)attributes cb:(void(^)(int32_t,NSString *,NSDictionary *))completion {
    self.timantirecall_calls++;self.timantirecall_ids=ids;self.timantirecall_source=source;
    self.timantirecall_destinations=destinations;self.timantirecall_attributes=attributes;
    self.timantirecall_completion=completion;self.timantirecall_onMain=NSThread.isMainThread;
    [QQMsgService getInstance].timantirecall_sendCalls++;
}
@end
static int64_t timantirecall_videoWrongForward(id object,SEL selector,id ids,id source,id destinations,id attributes,id callback) {
    (void)object;(void)selector;(void)ids;(void)source;(void)destinations;(void)attributes;(void)callback;
    TIMAntiRecallVideoForwardProbe.timantirecall_shared.timantirecall_calls++;return 0;
}
@implementation QQMsgService (TIMAntiRecallVideoFixture)
- (id)getMsgSenderHandlerWithcontact:(NTAIOContact *)contact {
    TIMAntiRecallVideoForwardProbe *probe=TIMAntiRecallVideoForwardProbe.timantirecall_shared;
    probe.timantirecall_getterCalls++;
    if(![contact convertToOCContact])return nil;
    if(probe.timantirecall_handlerMode==1)return nil;
    if(probe.timantirecall_handlerMode==2)return [NSObject new];
    if(probe.timantirecall_handlerMode==3) {
        Class bad=objc_getClass("TIMAntiRecallVideoWrongForwardABI");
        if(!bad) {
            bad=objc_allocateClassPair(object_getClass(probe),"TIMAntiRecallVideoWrongForwardABI",0);
            class_addMethod(bad,@selector(forwardMsgWithMsgIds:srcContact:dstContacts:msgAttributeInfos:cb:),(IMP)timantirecall_videoWrongForward,"q56@0:8@16@24@32@40@?48");
            objc_registerClassPair(bad);
        }
        return [[bad alloc] init];
    }
    return probe;
}
@end
