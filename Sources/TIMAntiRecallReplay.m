#import "TIMAntiRecallReplay.h"
#import "TIMAntiRecallReplayTrace.h"
#import "TIMAntiRecallReplayPayload.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallMarks.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import "TIMAntiRecall-Swift.h"
#include <math.h>
#include <string.h>


static IMP timantirecall_replayGetter(id object, SEL selector, const char *result) {
    if (!object) return NULL;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    const char *args[]={"@",":"};
    return timantirecall_methodTypes(method,result,2,args)?method_getImplementation(method):NULL;
}
static id timantirecall_replayObject(id object, const char *name, BOOL *valid) {
    SEL selector=sel_registerName(name);
    IMP getter=timantirecall_replayGetter(object,selector,"@");
    if (!getter) { if(valid)*valid=NO; return nil; }
    if(valid)*valid=YES;
    return ((id(*)(id,SEL))getter)(object,selector);
}
static BOOL timantirecall_replayInteger(id object,const char *name,const char *encoding,int64_t *value) {
    SEL selector=sel_registerName(name);
    IMP getter=timantirecall_replayGetter(object,selector,encoding);
    if(!getter)return NO;
    if(strcmp(encoding,"i")==0)*value=((int(*)(id,SEL))getter)(object,selector);
    else *value=((int64_t(*)(id,SEL))getter)(object,selector);
    return YES;
}
static NSString *timantirecall_plainTextForRecord(id record) {
#define REPLAY_REJECT(fieldName) do { timantirecall_replayTrace(@"text",@{@"reason":@"field-rejected",@"field":@#fieldName}); return nil; } while(0)
    Class recordClass=objc_getClass("OCMsgRecord"),elementClass=objc_getClass("OCMsgElement"),textClass=objc_getClass("OCTextElement");
    if(!recordClass||!elementClass||!textClass||![record isKindOfClass:recordClass])REPLAY_REJECT(recordClass);
    BOOL valid=NO;id elements=timantirecall_replayObject(record,"elements",&valid);
    if(!valid)REPLAY_REJECT(elements-abi);
    if(![elements isKindOfClass:NSArray.class]||[elements count]!=1)REPLAY_REJECT(elements-count);
    id element=((NSArray *)elements)[0];
    if(![element isKindOfClass:elementClass])REPLAY_REJECT(element-class);
    static const char *payloads[]={"faceElement","marketFaceElement","replyElement","picElement","pttElement","videoElement","grayTipElement","arkElement","fileElement","liveGiftElement","markdownElement","structLongMsgElement","multiForwardMsgElement","giphyElement","walletElement","inlineKeyboardElement","textGiftElement","calendarElement","yoloGameResultElement","avRecordElement","structMsgElement","faceBubbleElement","shareLocationElement","tofuRecordElement","taskTopMsgElement","recommendedMsgElement","actionBarElement","prologueMsgElement"};
    for(size_t i=0;i<sizeof(payloads)/sizeof(payloads[0]);i++) {
        id payload=timantirecall_replayObject(element,payloads[i],&valid);
        if(!valid)REPLAY_REJECT(payload-abi);
        if(payload) {timantirecall_replayTrace(@"text",@{@"reason":@"non-text-payload",@"field":[NSString stringWithUTF8String:payloads[i]]});return nil;}
    }
    id text=timantirecall_replayObject(element,"textElement",&valid);
    if(!valid)REPLAY_REJECT(textElement-abi);
    if(![text isKindOfClass:textClass])REPLAY_REJECT(textElement-class);
    int64_t number=0;
    if(!timantirecall_replayInteger(text,"atType","i",&number))REPLAY_REJECT(atType-abi);
    if(number!=0)REPLAY_REJECT(atType-value);
    if(!timantirecall_replayInteger(text,"atUid","q",&number))REPLAY_REJECT(atUid-abi);
    if(number!=0)REPLAY_REJECT(atUid-value);
    if(!timantirecall_replayInteger(text,"atTinyId","q",&number))REPLAY_REJECT(atTinyId-abi);
    if(number!=0)REPLAY_REJECT(atTinyId-value);
    static const char *metadata[]={"atNtUid","subElementType","atChannelId","linkInfo","atRoleId","atRoleColor","atRoleName"};
    for(size_t i=0;i<sizeof(metadata)/sizeof(metadata[0]);i++) {
        id value=timantirecall_replayObject(text,metadata[i],&valid);
        if(!valid){timantirecall_replayTrace(@"text",@{@"reason":@"getter-abi",@"field":[NSString stringWithUTF8String:metadata[i]]});return nil;}
        if(!value)continue;
        NSString *valueClass=NSStringFromClass([value class])?:@"unknown";
        if([value isKindOfClass:NSString.class]) {
            if([value length]!=0){timantirecall_replayTrace(@"text",@{@"reason":@"metadata-nonempty",@"field":[NSString stringWithUTF8String:metadata[i]],@"valueClass":valueClass,@"valueKind":@"string"});return nil;}
            continue;
        }
        BOOL nativePlainTextZero=(strcmp(metadata[i],"subElementType")==0||strcmp(metadata[i],"atChannelId")==0||strcmp(metadata[i],"atRoleId")==0||strcmp(metadata[i],"atRoleColor")==0);
        if(nativePlainTextZero&&[value isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()&&[value isEqualToNumber:@0])continue;
        NSString *valueKind=@"other";
        if([value isKindOfClass:NSNumber.class]) {
            if(CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID())valueKind=@"number-boolean";
            else valueKind=[value isEqualToNumber:@0]?@"number-zero":@"number-nonzero";
        } else if([value isKindOfClass:NSString.class])valueKind=@"string";
        else if([value isKindOfClass:NSNull.class])valueKind=@"null-object";
        timantirecall_replayTrace(@"text",@{@"reason":@"metadata-type",@"field":[NSString stringWithUTF8String:metadata[i]],@"valueClass":valueClass,@"valueKind":valueKind});return nil;
    }
    NSString *content=timantirecall_replayObject(text,"content",&valid);
    if(!valid){timantirecall_replayTrace(@"text",@{@"reason":@"content-abi",@"field":@"content"});return nil;}
    if(![content isKindOfClass:NSString.class]||content.length>4096) {timantirecall_replayTrace(@"text",@{@"reason":@"content-shape",@"field":@"content"});return nil;}
    if([content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length==0) {timantirecall_replayTrace(@"text",@{@"reason":@"content-empty",@"field":@"content"});return nil;}
    return content;
}
#undef REPLAY_REJECT
static NSDictionary *timantirecall_replayContent(id record) {
    NSString *text=timantirecall_plainTextForRecord(record);
    return text?@{@"mode":@"text",@"text":[text copy]}:timantirecall_richReplaySnapshot(record);
}
static BOOL timantirecall_replayWindowActive(UIWindow *window) {
    if(!window||window.hidden||window.alpha<0.01)return NO;
    if(window.windowScene)return window.windowScene.activationState==UISceneActivationStateForegroundActive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
#pragma clang diagnostic pop
}
@class TIMAntiRecallReplayContext;
@interface TIMAntiRecallReplayTap : UITapGestureRecognizer
@property(nonatomic,weak) TIMAntiRecallReplayContext *timantirecall_context;
@end
@interface TIMAntiRecallReplayContext : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic,weak) UIView *timantirecall_row,*timantirecall_host;
@property(nonatomic,strong) TIMAntiRecallReplayTap *timantirecall_tap;
@property(nonatomic,weak) id timantirecall_boundModel,timantirecall_firstModel;
@property(nonatomic,weak) UIViewController *timantirecall_firstController;
@property(nonatomic,weak) UIScrollView *timantirecall_firstScroll;
@property(nonatomic,weak) id timantirecall_firstChatContext;
@property(nonatomic,copy) NSString *timantirecall_owner;
@property(nonatomic,copy) NSDictionary *timantirecall_firstIdentity,*timantirecall_firstPayload;
@property(nonatomic) CGPoint timantirecall_firstPoint,timantirecall_firstOffset;
@property(nonatomic) CGRect timantirecall_firstBubble;
@property(nonatomic) NSTimeInterval timantirecall_firstTime;
@property(nonatomic) NSUInteger timantirecall_epoch,timantirecall_samples;
@property(nonatomic,strong) NSObject *timantirecall_scrollObservation;
- (void)timantirecall_clear;
- (BOOL)timantirecall_capture:(CGPoint)point time:(NSTimeInterval)time;
- (BOOL)timantirecall_complete:(CGPoint)point;
- (void)timantirecall_action:(UITapGestureRecognizer *)tap;
@end
static char timantirecall_replayRowKey,timantirecall_replayHostKey,timantirecall_replayCandidatesKey;
static NSUInteger timantirecall_replayEpoch;
static BOOL timantirecall_replayInstalled;
static BOOL timantirecall_replayRectValid(CGRect rect) {
    return !CGRectIsNull(rect)&&!CGRectIsInfinite(rect)&&!CGRectIsEmpty(rect)&&
        isfinite(rect.origin.x)&&isfinite(rect.origin.y)&&isfinite(rect.size.width)&&isfinite(rect.size.height);
}
static UIView *timantirecall_replayHost(UIView *row) {
    UIView *view=row;
    for(unsigned depth=0;view&&depth<16;depth++,view=view.superview) {
        if([view isKindOfClass:UITableViewCell.class])return ((UITableViewCell *)view).contentView;
        if([view isKindOfClass:UICollectionViewCell.class])return ((UICollectionViewCell *)view).contentView;
    }
    return row;
}
static UIViewController *timantirecall_replayController(UIView *row) {
    UIResponder *cursor=row;
    for(unsigned depth=0;cursor&&depth<40;depth++,cursor=cursor.nextResponder) {
        if(![cursor isKindOfClass:UIViewController.class])continue;
        UIViewController *controller=(UIViewController *)cursor;
        for(unsigned parents=0;controller&&parents<12;parents++,controller=controller.parentViewController)
            if([TIMAntiRecallRecordBridge timantirecall_replayChatContextForController:controller])return controller;
    }
    return nil;
}
static UIScrollView *timantirecall_replayScroll(UIView *host) {
    for(UIView *view=host;view;view=view.superview)
        if([view isKindOfClass:UIScrollView.class])return (UIScrollView *)view;
    return nil;
}
static BOOL timantirecall_replayHostUnique(UIView *host,UIView *row) {
    NSHashTable *candidates=objc_getAssociatedObject(host,&timantirecall_replayCandidatesKey);
    unsigned visible=0,budget=16;BOOL found=NO;
    for(UIView *candidate in candidates.allObjects) {
        if(!budget--)return NO;
        if(candidate.window&&candidate.window==host.window&&timantirecall_replayHost(candidate)==host&&
           [TIMAntiRecallRecordBridge timantirecall_currentModelForView:candidate]&&
           [TIMAntiRecallRecordBridge timantirecall_replayViewsForRow:candidate][@"content"]) {
            visible++;if(candidate==row)found=YES;
        }
    }
    return found&&visible==1;
}
static id timantirecall_replayContact(id record,UIViewController *controller);
static BOOL timantirecall_replayContextAtPoint(TIMAntiRecallReplayContext *state,CGPoint point,
        id *modelOut,NSDictionary **identityOut,UIViewController **controllerOut,CGRect *bubbleOut,NSDictionary **payloadOut) {
    UIView *row=state.timantirecall_row,*host=state.timantirecall_host;
    NSString *owner=timantirecall_currentAccount();
    if(!NSThread.isMainThread){timantirecall_replayTrace(@"gate",@{@"reason":@"off-main-thread"});return NO;}
    if(![timantirecall_settings() timantirecall_messageReplay]){timantirecall_replayTrace(@"gate",@{@"reason":@"feature-disabled"});return NO;}
    if(!row||!host||timantirecall_replayHost(row)!=host||row.window!=host.window||!timantirecall_replayHostUnique(host,row)){timantirecall_replayTrace(@"gate",@{@"reason":@"host-invalid"});return NO;}
    if(!timantirecall_replayWindowActive(host.window)){timantirecall_replayTrace(@"gate",@{@"reason":@"window-inactive"});return NO;}
    if(![owner isEqual:state.timantirecall_owner]){timantirecall_replayTrace(@"gate",@{@"reason":@"owner-changed"});return NO;}
    if(!CGRectContainsPoint(host.bounds,point)){timantirecall_replayTrace(@"gate",@{@"reason":@"point-outside-host",@"x":@(point.x),@"y":@(point.y),@"hw":@(host.bounds.size.width),@"hh":@(host.bounds.size.height)});return NO;}
    for(UIView *v=row;v;v=v.superview) {
        if(v.hidden||v.alpha<0.01||!v.userInteractionEnabled){timantirecall_replayTrace(@"gate",@{@"reason":@"ancestor-not-interactive"});return NO;}
        if([v isKindOfClass:UIScrollView.class]&&(((UIScrollView *)v).dragging||((UIScrollView *)v).decelerating)){timantirecall_replayTrace(@"gate",@{@"reason":@"scroll-active"});return NO;}
    }
    id model=[TIMAntiRecallRecordBridge timantirecall_currentModelForView:row];
    if(!model||model!=state.timantirecall_boundModel){timantirecall_replayTrace(@"gate",@{@"reason":@"model-not-current"});return NO;}
    id record=[TIMAntiRecallRecordBridge timantirecall_recordForViewModel:model];
    NSDictionary *payload=timantirecall_replayContent(record);
    if(!payload){timantirecall_replayTrace(@"gate",@{@"reason":@"message-not-eligible",@"field":@"payload"});return NO;}
    NSDictionary *identity=timantirecall_recordIdentity(record,owner);
    if(!identity){timantirecall_replayTrace(@"gate",@{@"reason":@"message-identity-rejected",@"field":@"record"});return NO;}
    UIViewController *controller=timantirecall_replayController(row);
    if(!controller||!controller.isViewLoaded||controller.view.window!=host.window||controller.view.hidden||
       ![row isDescendantOfView:controller.view]||controller.presentedViewController){timantirecall_replayTrace(@"gate",@{@"reason":@"chat-controller-invalid"});return NO;}
    UIViewController *top=controller.navigationController.topViewController;
    if(top&&top!=controller&&(!top.isViewLoaded||![controller.view isDescendantOfView:top.view])){timantirecall_replayTrace(@"gate",@{@"reason":@"chat-not-top-controller"});return NO;}
    if(!timantirecall_replayContact(record,controller)){timantirecall_replayTrace(@"gate",@{@"reason":@"record-contact-mismatch"});return NO;}
    NSDictionary<NSString *,UIView *> *views=[TIMAntiRecallRecordBridge timantirecall_replayViewsForRow:row];
    UIView *content=views[@"content"];
    if(!content||content.window!=host.window||content.hidden||content.alpha<0.01||![content isDescendantOfView:row]){timantirecall_replayTrace(@"gate",@{@"reason":@"content-view-invalid"});return NO;}
    CGRect bubble=[content convertRect:content.bounds toView:host];
    if(!timantirecall_replayRectValid(bubble)||bubble.size.width<8||bubble.size.height<8||!CGRectContainsRect(host.bounds,bubble)){
        timantirecall_replayTrace(@"gate",@{@"reason":@"bubble-rect-invalid",@"bw":@(bubble.size.width),@"bh":@(bubble.size.height),@"hw":@(host.bounds.size.width),@"hh":@(host.bounds.size.height)});return NO;
    }
    BOOL outgoing=[identity[@"author"] isEqual:owner];
    CGFloat left=outgoing?CGRectGetMinX(host.bounds)+6:CGRectGetMaxX(bubble)+6;
    CGFloat right=outgoing?CGRectGetMinX(bubble)-6:CGRectGetMaxX(host.bounds)-6;
    CGRect rowArea=CGRectInset(host.bounds,0,4);
    CGRect band=CGRectMake(left,CGRectGetMinY(rowArea),right-left,rowArea.size.height);
    if(!timantirecall_replayRectValid(band)||!CGRectContainsPoint(band,point)){timantirecall_replayTrace(@"gate",@{@"reason":@"point-outside-bubble-side-band",@"x":@(point.x),@"y":@(point.y),@"bx":@(CGRectGetMinX(bubble)),@"by":@(CGRectGetMinY(bubble)),@"bw":@(bubble.size.width),@"bh":@(bubble.size.height),@"hw":@(host.bounds.size.width),@"hh":@(host.bounds.size.height)});return NO;}
    for(UIView *excluded in views.allValues) {
        if(excluded.window!=host.window||excluded.hidden||excluded.alpha<0.01)continue;
        CGRect rect=[excluded convertRect:excluded.bounds toView:host];
        if(CGRectIsEmpty(rect))continue;
        if(!timantirecall_replayRectValid(rect)||CGRectContainsPoint(CGRectInset(rect,-4,-4),point)){timantirecall_replayTrace(@"gate",@{@"reason":@"interactive-subview-hit"});return NO;}
    }
    UIView *hit=[host hitTest:point withEvent:nil];
    if(!hit){timantirecall_replayTrace(@"gate",@{@"reason":@"hit-test-nil"});return NO;}
    for(UIView *v=hit;v&&v!=host;v=v.superview)
        if([v isKindOfClass:UIControl.class]||[v isKindOfClass:UITextView.class]||[v isKindOfClass:UILabel.class]||[v isKindOfClass:UIImageView.class]){timantirecall_replayTrace(@"gate",@{@"reason":@"hit-test-excluded-view",@"contentClass":NSStringFromClass(v.class)});return NO;}
    if(modelOut)*modelOut=model;if(identityOut)*identityOut=identity;
    if(payloadOut)*payloadOut=payload;
    if(controllerOut)*controllerOut=controller;if(bubbleOut)*bubbleOut=bubble;
    return YES;
}
static id timantirecall_replayContact(id record,UIViewController *controller) {
    id context=[TIMAntiRecallRecordBridge timantirecall_replayChatContextForController:controller];
    if(!context)return nil;
    BOOL valid=NO;id contact=timantirecall_replayObject(record,"contact",&valid);
    Class contactClass=objc_getClass("OCContact");
    if(!valid||!contactClass||![contact isKindOfClass:contactClass])return nil;
    int64_t recordType=0,currentType=0;
    if(!timantirecall_replayInteger(contact,"chatType","i",&recordType)||
       !timantirecall_replayInteger(context,"chatType","i",&currentType)||
       (recordType!=1&&recordType!=2)||recordType!=currentType)return nil;
    id recordPeer=timantirecall_replayObject(contact,"peerUid",&valid);
    if(!valid||![recordPeer isKindOfClass:NSString.class]||![recordPeer length])return nil;
    id currentPeer=timantirecall_replayObject(context,"peerUid",&valid);
    if(!valid||![currentPeer isKindOfClass:NSString.class]||![recordPeer isEqual:currentPeer])return nil;
    return contact;
}
static BOOL timantirecall_replaySend(id record,UIViewController *controller,NSDictionary *payload) {
    id contact=timantirecall_replayContact(record,controller);
    if(!contact||!payload||![payload isEqual:timantirecall_replayContent(record)])return NO;
    Class cls=objc_getClass("QQMsgService");SEL shared=sel_registerName("getInstance");
    const char *getterArgs[]={"@",":"};
    Method getter=cls?class_getClassMethod(cls,shared):NULL;
    if(!timantirecall_methodTypes(getter,"@",2,getterArgs))return NO;
    id service=((id(*)(id,SEL))method_getImplementation(getter))(cls,shared);
    if(!service||![service isKindOfClass:cls])return NO;
    if(![payload[@"mode"] isEqual:@"text"])return timantirecall_richReplaySend(service,contact,record,payload);
    NSString *text=payload[@"text"];if(!text.length)return NO;
    SEL selector=sel_registerName("sendTextMsgByOCContact:richText:callBack:");
    Method method=class_getInstanceMethod(object_getClass(service),selector);
    const char *args[]={"@",":","@","@","@?"};
    if(!timantirecall_methodTypes(method,"v",5,args))return NO;
    // Only nil is passed. Do not invent or invoke the private callback signature.
    ((void(*)(id,SEL,id,id,void(^)(void)))method_getImplementation(method))(service,selector,contact,text,nil);
    return YES; // Submitted once to the native service, NOT a delivery receipt.
}
static BOOL timantirecall_replayStartPhotoDownload(id record,NSDictionary *payload,NSDictionary *identity,UIViewController *controller,id chatContext,NSString *owner) {
    if(!NSThread.isMainThread||!record||!identity||!controller||!chatContext||!owner.length||![payload[@"mode"] isEqual:@"photo-download"])return NO;
    id contact=timantirecall_replayContact(record,controller);if(!contact)return NO;
    Class cls=objc_getClass("QQMsgService");SEL shared=sel_registerName("getInstance");const char *args[]={"@",":"};
    Method getter=cls?class_getClassMethod(cls,shared):NULL;if(!timantirecall_methodTypes(getter,"@",2,args))return NO;
    id service=((id(*)(id,SEL))method_getImplementation(getter))(cls,shared);if(!service||![service isKindOfClass:cls])return NO;
    __weak UIViewController *weakController=controller;__weak UIWindow *weakWindow=controller.view.window;
    BOOL (^shouldContinue)(void)=^BOOL{
        UIViewController *liveController=weakController;UIWindow *window=weakWindow;
        if(!NSThread.isMainThread||!liveController||!window||
           ![timantirecall_settings() timantirecall_messageReplay]||![owner isEqual:timantirecall_currentAccount()]||
           !timantirecall_replayWindowActive(window)||!liveController.isViewLoaded||liveController.view.window!=window||
           liveController.presentedViewController||[TIMAntiRecallRecordBridge timantirecall_replayChatContextForController:liveController]!=chatContext)return NO;
        UIViewController *top=liveController.navigationController.topViewController;
        if(top&&top!=liveController&&(!top.isViewLoaded||![liveController.view isDescendantOfView:top.view]))return NO;
        NSDictionary *currentIdentity=timantirecall_recordIdentity(record,owner);
        return [currentIdentity isEqualToDictionary:identity]&&timantirecall_replayContact(record,liveController)!=nil;
    };
    BOOL started=timantirecall_richReplaySendWithPhotoDownload(service,contact,record,payload,^(NSDictionary *file,NSNumber *subtype){
#ifdef TIMANTIRECALL_UI_TEST
        NSLog(@"TIMANTI_PHOTO_CALLBACK fileReady=%d",file!=nil);
#endif
        if(!file)return;
        BOOL contextValid=shouldContinue();
#ifdef TIMANTIRECALL_UI_TEST
        NSLog(@"TIMANTI_PHOTO_CALLBACK contextValid=%d",contextValid);
#endif
        if(!contextValid) {timantirecall_replayTrace(@"send",@{@"reason":@"photo-download-context-expired"});return;}
        NSDictionary *currentPayload=timantirecall_replayContent(record);
        id currentContact=timantirecall_replayContact(record,controller);
        BOOL samePayload=[currentPayload isEqual:payload];
        BOOL resolvedTransition=[payload[@"mode"] isEqual:@"photo-download"]&&[currentPayload[@"mode"] isEqual:@"photo"]&&
            [currentPayload[@"subtype"] isEqual:subtype]&&[currentPayload[@"file"] isEqual:file];
#ifdef TIMANTIRECALL_UI_TEST
        NSLog(@"TIMANTI_PHOTO_CALLBACK payloadSame=%d resolvedTransition=%d contact=%d",samePayload,resolvedTransition,currentContact!=nil);
#endif
        if((!samePayload&&!resolvedTransition)||!currentContact) {
            timantirecall_replayTrace(@"send",@{@"reason":@"photo-download-record-changed"});return;
        }
        BOOL submitted=timantirecall_richReplaySendDownloadedPhoto(service,currentContact,record,file,subtype);
#ifdef TIMANTIRECALL_UI_TEST
        NSLog(@"TIMANTI_PHOTO_CALLBACK submitted=%d",submitted);
#endif
        timantirecall_replayTrace(@"send",@{@"reason":submitted?@"photo-download-native-submit-called":@"photo-download-native-submit-rejected"});
    },shouldContinue);
    if(started)timantirecall_replayTrace(@"send",@{@"reason":@"photo-original-download-started"});
    return started;
}
@implementation TIMAntiRecallReplayTap
- (void)reset {
#ifdef TIMANTIRECALL_UI_TEST
    NSLog(@"REPLAY_TOUCH reset samples=%lu",(unsigned long)self.timantirecall_context.timantirecall_samples);
#endif
    [super reset];[self.timantirecall_context timantirecall_clear];
}
@end
@implementation TIMAntiRecallReplayContext
- (void)dealloc {
    UIView *host=_timantirecall_host;UITapGestureRecognizer *tap=_timantirecall_tap;
    if(NSThread.isMainThread)[host removeGestureRecognizer:tap];
    else if(host&&tap)dispatch_async(dispatch_get_main_queue(),^{[host removeGestureRecognizer:tap];});
}
- (void)timantirecall_clear {
    self.timantirecall_firstModel=nil;self.timantirecall_firstIdentity=nil;self.timantirecall_firstPayload=nil;
    self.timantirecall_firstController=nil;self.timantirecall_firstScroll=nil;self.timantirecall_firstChatContext=nil;
    self.timantirecall_samples=0;self.timantirecall_firstTime=0;
}
- (BOOL)timantirecall_capture:(CGPoint)point time:(NSTimeInterval)time {
    id model=nil;NSDictionary *identity=nil,*payload=nil;UIViewController *controller=nil;CGRect bubble=CGRectZero;
    if(!timantirecall_replayContextAtPoint(self,point,&model,&identity,&controller,&bubble,&payload)) {
        [self timantirecall_clear];return NO;
    }
    UIScrollView *scroll=timantirecall_replayScroll(self.timantirecall_host);
    if(self.timantirecall_samples==0||time-self.timantirecall_firstTime>0.7) {
        [self timantirecall_clear];self.timantirecall_firstModel=model;self.timantirecall_firstIdentity=identity;
        self.timantirecall_firstPayload=payload;
        self.timantirecall_firstController=controller;self.timantirecall_firstScroll=scroll;
        self.timantirecall_firstChatContext=[TIMAntiRecallRecordBridge timantirecall_replayChatContextForController:controller];
        self.timantirecall_firstOffset=(scroll?scroll.contentOffset:CGPointZero);self.timantirecall_firstBubble=bubble;
        self.timantirecall_firstPoint=point;self.timantirecall_firstTime=time;
        self.timantirecall_epoch=timantirecall_replayEpoch;self.timantirecall_samples=1;return YES;
    }
    BOOL same=self.timantirecall_samples==1&&model==self.timantirecall_firstModel&&
        [payload isEqual:self.timantirecall_firstPayload]&&controller==self.timantirecall_firstController&&
        [TIMAntiRecallRecordBridge timantirecall_replayChatContextForController:controller]==self.timantirecall_firstChatContext&&[identity isEqualToDictionary:self.timantirecall_firstIdentity]&&
        self.timantirecall_epoch==timantirecall_replayEpoch&&time>=self.timantirecall_firstTime&&
        scroll==self.timantirecall_firstScroll&&CGPointEqualToPoint((scroll?scroll.contentOffset:CGPointZero),self.timantirecall_firstOffset)&&
        CGRectEqualToRect(bubble,self.timantirecall_firstBubble)&&
        hypot(point.x-self.timantirecall_firstPoint.x,point.y-self.timantirecall_firstPoint.y)<=20;
    if(!same){timantirecall_replayTrace(@"capture",@{@"reason":@"second-tap-context-changed"});[self timantirecall_clear];return NO;}
    self.timantirecall_samples=2;return YES;
}
- (BOOL)timantirecall_complete:(CGPoint)point {
    id model=nil;NSDictionary *identity=nil,*payload=nil;UIViewController *controller=nil;CGRect bubble=CGRectZero;
    BOOL valid=self.timantirecall_samples==2&&self.timantirecall_epoch==timantirecall_replayEpoch&&
        timantirecall_replayContextAtPoint(self,point,&model,&identity,&controller,&bubble,&payload)&&
        model==self.timantirecall_firstModel&&controller==self.timantirecall_firstController&&
        [TIMAntiRecallRecordBridge timantirecall_replayChatContextForController:controller]==self.timantirecall_firstChatContext&&
        [payload isEqual:self.timantirecall_firstPayload]&&[identity isEqualToDictionary:self.timantirecall_firstIdentity]&&CGRectEqualToRect(bubble,self.timantirecall_firstBubble);
    UIScrollView *scroll=timantirecall_replayScroll(self.timantirecall_host);
    valid=valid&&scroll==self.timantirecall_firstScroll&&CGPointEqualToPoint((scroll?scroll.contentOffset:CGPointZero),self.timantirecall_firstOffset);
    NSDictionary *accepted=valid?payload:nil;
    id acceptedRecord=accepted?[TIMAntiRecallRecordBridge timantirecall_recordForViewModel:model]:nil;
    NSDictionary *acceptedIdentity=accepted?self.timantirecall_firstIdentity:nil;
    UIViewController *acceptedController=accepted?self.timantirecall_firstController:nil;
    id acceptedContext=accepted?self.timantirecall_firstChatContext:nil;
    NSString *acceptedOwner=[self.timantirecall_owner copy];
    [self timantirecall_clear];
    BOOL submitted=NO;
    if([accepted[@"mode"] isEqual:@"photo-download"])
        submitted=timantirecall_replayStartPhotoDownload(acceptedRecord,accepted,acceptedIdentity,acceptedController,acceptedContext,acceptedOwner);
    else submitted=accepted?timantirecall_replaySend(acceptedRecord,acceptedController,accepted):NO;
    timantirecall_replayTrace(@"send",@{@"reason":submitted?([accepted[@"mode"] isEqual:@"photo-download"]?@"photo-original-download-started":@"native-submit-called"):@"completed-context-or-service-rejected"});
    return submitted;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    BOOL isReplay=gesture==self.timantirecall_tap;
    CGPoint point=[touch locationInView:self.timantirecall_host];
    BOOL accepted=isReplay&&[self timantirecall_capture:point time:touch.timestamp];
    if(isReplay)timantirecall_replayTrace(@"touch",@{@"reason":accepted?@"accepted":@"delegate-rejected",@"tapCount":@(touch.tapCount),@"samples":@(self.timantirecall_samples),@"x":@(point.x),@"y":@(point.y)});
#ifdef TIMANTIRECALL_UI_TEST
    NSLog(@"REPLAY_TOUCH delegate accepted=%d tapCount=%lu samples=%lu state=%ld",accepted,(unsigned long)touch.tapCount,(unsigned long)self.timantirecall_samples,(long)gesture.state);
#endif
    return accepted;
}
- (void)timantirecall_action:(UITapGestureRecognizer *)tap {
    timantirecall_replayTrace(@"action",@{@"reason":tap==self.timantirecall_tap&&tap.state==UIGestureRecognizerStateRecognized?@"recognized":@"state-rejected",@"samples":@(self.timantirecall_samples),@"state":@(tap.state)});
#ifdef TIMANTIRECALL_UI_TEST
    NSLog(@"REPLAY_TOUCH action state=%ld samples=%lu",(long)tap.state,(unsigned long)self.timantirecall_samples);
#endif
    if(tap==self.timantirecall_tap&&tap.state==UIGestureRecognizerStateRecognized)
        [self timantirecall_complete:[tap locationInView:self.timantirecall_host]];
}
@end
void timantirecall_clearReplayRow(UIView *row) {
    if(!NSThread.isMainThread||!row)return;
    TIMAntiRecallReplayContext *state=objc_getAssociatedObject(row,&timantirecall_replayRowKey);
    [state timantirecall_clear];state.timantirecall_scrollObservation=nil;
    UIView *oldHost=state.timantirecall_host?:timantirecall_replayHost(row);
    [(NSHashTable *)objc_getAssociatedObject(oldHost,&timantirecall_replayCandidatesKey) removeObject:row];
    [state.timantirecall_host removeGestureRecognizer:state.timantirecall_tap];
    if(state&&objc_getAssociatedObject(state.timantirecall_host,&timantirecall_replayHostKey)==state)
        objc_setAssociatedObject(state.timantirecall_host,&timantirecall_replayHostKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(row,&timantirecall_replayRowKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void timantirecall_updateReplayRow(UIView *row,NSString *boundOwner) {
    if(!NSThread.isMainThread||![row isKindOfClass:UIView.class])return;
    if(!row.window||![timantirecall_settings() timantirecall_messageReplay]){timantirecall_clearReplayRow(row);return;}
    if(![boundOwner isKindOfClass:NSString.class]||!boundOwner.length) {timantirecall_replayTrace(@"attach",@{@"reason":@"owner-missing"});timantirecall_clearReplayRow(row);return;}
    id model=[TIMAntiRecallRecordBridge timantirecall_currentModelForView:row];
    NSString *owner=timantirecall_currentAccount();
    NSDictionary *views=[TIMAntiRecallRecordBridge timantirecall_replayViewsForRow:row];
    if(!row.window||![timantirecall_settings() timantirecall_messageReplay]||!model||!owner.length||![owner isEqual:boundOwner]||!views[@"content"]) {
        timantirecall_replayTrace(@"attach",@{@"reason":@"row-context-incomplete",@"rowClass":NSStringFromClass(row.class),@"contentClass":(NSStringFromClass([views[@"content"] class])?:@"none"),@"modelClass":(NSStringFromClass([model class])?:@"none")});
        timantirecall_clearReplayRow(row);return;
    }
    UIView *host=timantirecall_replayHost(row);
    TIMAntiRecallReplayContext *state=objc_getAssociatedObject(row,&timantirecall_replayRowKey);
    if(state&&state.timantirecall_host==host&&state.timantirecall_boundModel==model&&[state.timantirecall_owner isEqual:owner]){
        timantirecall_replayTrace(@"attach",@{@"reason":@"already-installed",@"rowClass":NSStringFromClass(row.class),@"hostClass":NSStringFromClass(host.class)});return;
    }
    timantirecall_clearReplayRow(row);
    NSHashTable *candidates=objc_getAssociatedObject(host,&timantirecall_replayCandidatesKey);
    if(!candidates){candidates=[NSHashTable weakObjectsHashTable];objc_setAssociatedObject(host,&timantirecall_replayCandidatesKey,candidates,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    [candidates addObject:row];
    TIMAntiRecallReplayContext *other=objc_getAssociatedObject(host,&timantirecall_replayHostKey);
    if(other&&other.timantirecall_row&&other.timantirecall_row!=row&&other.timantirecall_row.window==host.window) {
        [other timantirecall_clear];timantirecall_replayTrace(@"attach",@{@"reason":@"host-ambiguous",@"hostClass":NSStringFromClass(host.class)});return;
    }
    state=[TIMAntiRecallReplayContext new];state.timantirecall_row=row;state.timantirecall_host=host;
    state.timantirecall_boundModel=model;state.timantirecall_owner=owner;
    TIMAntiRecallReplayTap *tap=[[TIMAntiRecallReplayTap alloc] initWithTarget:state action:@selector(timantirecall_action:)];
    tap.timantirecall_context=state;tap.delegate=state;tap.numberOfTapsRequired=2;tap.numberOfTouchesRequired=1;
    tap.cancelsTouchesInView=NO;tap.delaysTouchesBegan=NO;tap.delaysTouchesEnded=NO;state.timantirecall_tap=tap;
    UIScrollView *scroll=timantirecall_replayScroll(host);
    if(scroll) {
        [tap requireGestureRecognizerToFail:scroll.panGestureRecognizer];
        __weak TIMAntiRecallReplayContext *weakState=state;
        state.timantirecall_scrollObservation=[TIMAntiRecallRecordBridge timantirecall_observeReplayScroll:scroll changed:^{[weakState timantirecall_clear];}];
    }
    objc_setAssociatedObject(row,&timantirecall_replayRowKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(host,&timantirecall_replayHostKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [host addGestureRecognizer:tap];
    timantirecall_replayTrace(@"attach",@{@"reason":@"gesture-installed",@"rowClass":NSStringFromClass(row.class),@"hostClass":NSStringFromClass(host.class),@"contentClass":(NSStringFromClass([views[@"content"] class])?:@"none")});
}
BOOL timantirecall_installMessageReplay(void) {
    if(!NSThread.isMainThread)return NO;
    if(timantirecall_replayInstalled)return YES;
    NSMutableArray *tokens=[NSMutableArray array];
    for(NSNotificationName name in @[TIMAntiRecallSettingsChangedNotification,TIMAntiRecallStateChangedNotification,
        UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UISceneWillDeactivateNotification])
        [tokens addObject:[NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *note){timantirecall_replayEpoch++;}]];
    static NSArray *timantirecall_replayObservers;timantirecall_replayObservers=[tokens copy];(void)timantirecall_replayObservers;
    timantirecall_replayInstalled=YES;return YES;
}
#ifdef TIMANTIRECALL_UI_TEST
BOOL timantirecall_testReplayCapture(UIView *row,CGPoint point,NSTimeInterval time) {
    TIMAntiRecallReplayContext *state=objc_getAssociatedObject(row,&timantirecall_replayRowKey);
    return state&&[state timantirecall_capture:point time:time];
}
BOOL timantirecall_testReplayComplete(UIView *row,CGPoint point) {
    TIMAntiRecallReplayContext *state=objc_getAssociatedObject(row,&timantirecall_replayRowKey);
    return state&&[state timantirecall_complete:point];
}
#endif
