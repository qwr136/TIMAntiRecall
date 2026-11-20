#import "TIMAntiRecallReplay.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallMarks.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdatomic.h>
#include <string.h>

static _Atomic(IMP) timantirecall_replayOriginal;
static BOOL timantirecall_replayInstalled;

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
    Class recordClass=objc_getClass("OCMsgRecord"),elementClass=objc_getClass("OCMsgElement"),textClass=objc_getClass("OCTextElement");
    if(!recordClass||!elementClass||!textClass||![record isKindOfClass:recordClass])return nil;
    BOOL valid=NO;id elements=timantirecall_replayObject(record,"elements",&valid);
    if(!valid||![elements isKindOfClass:NSArray.class]||[elements count]!=1)return nil;
    id element=elements.firstObject;
    if(![element isKindOfClass:elementClass])return nil;
    static const char *payloads[]={"faceElement","marketFaceElement","replyElement","picElement","pttElement","videoElement","grayTipElement","arkElement","fileElement","liveGiftElement","markdownElement","structLongMsgElement","multiForwardMsgElement","giphyElement","walletElement","inlineKeyboardElement","textGiftElement","calendarElement","yoloGameResultElement","avRecordElement","structMsgElement","faceBubbleElement","shareLocationElement","tofuRecordElement","taskTopMsgElement","recommendedMsgElement","actionBarElement","prologueMsgElement"};
    for(size_t i=0;i<sizeof(payloads)/sizeof(payloads[0]);i++) {
        id payload=timantirecall_replayObject(element,payloads[i],&valid);
        if(!valid||payload)return nil;
    }
    id text=timantirecall_replayObject(element,"textElement",&valid);
    if(!valid||![text isKindOfClass:textClass])return nil;
    int64_t number=0;
    if(!timantirecall_replayInteger(text,"atType","i",&number)||number!=0||
       !timantirecall_replayInteger(text,"atUid","q",&number)||number!=0||
       !timantirecall_replayInteger(text,"atTinyId","q",&number)||number!=0)return nil;
    static const char *metadata[]={"atNtUid","subElementType","atChannelId","linkInfo","atRoleId","atRoleColor","atRoleName"};
    for(size_t i=0;i<sizeof(metadata)/sizeof(metadata[0]);i++) {
        id value=timantirecall_replayObject(text,metadata[i],&valid);
        if(!valid||value)return nil;
    }
    NSString *content=timantirecall_replayObject(text,"content",&valid);
    if(!valid||![content isKindOfClass:NSString.class]||content.length>4096||
       [content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length==0)return nil;
    return content;
}
static BOOL timantirecall_replayWindowActive(UIWindow *window) {
    if(!window||window.hidden||window.alpha<0.01)return NO;
    if(window.windowScene)return window.windowScene.activationState==UISceneActivationStateForegroundActive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
#pragma clang diagnostic pop
}
static BOOL timantirecall_replayTextForContext(id record,id controller,id tappedCell,NSString **textOut) {
    if(!NSThread.isMainThread||![timantirecall_settings() timantirecall_messageReplay])return NO;
    Class controllerClass=objc_getClass("QQChatViewController");
    if(!controllerClass||![controller isKindOfClass:controllerClass]||![controller isViewLoaded])return NO;
    Class sendClass=objc_getClass("QQBaseChatViewController");
    if(!sendClass)return NO;
    UIViewController *chat=(UIViewController *)controller;
    UIWindow *window=chat.view.window;
    if(!timantirecall_replayWindowActive(window)||chat.view.hidden||
       (chat.navigationController&&chat.navigationController.topViewController!=chat)||chat.presentedViewController||
       ![tappedCell isKindOfClass:UIView.class]||[(UIView *)tappedCell window]!=window||
       ![(UIView *)tappedCell isDescendantOfView:chat.view])return NO;
    NSString *text=timantirecall_plainTextForRecord(record);
    if(!text)return NO;
    SEL selector=sel_registerName("sendTextMsg:showText:");
    Method method=class_getInstanceMethod(object_getClass(controller),selector);
    Method base=class_getInstanceMethod(sendClass,selector);
    const char *args[]={"@",":","@","@"};
    if(!timantirecall_methodTypes(method,"B",4,args)||!base||
       method_getImplementation(method)==method_getImplementation(base))return NO;
    if(textOut)*textOut=text;
    return YES;
}
static void timantirecall_replayDoubleTap(id receiver,SEL selector,id gesture,id record,id viewController,id tappedCellView) {
    NSString *text=nil;
    if(timantirecall_replayTextForContext(record,viewController,tappedCellView,&text)) {
        SEL sendSelector=sel_registerName("sendTextMsg:showText:");
        IMP send=method_getImplementation(class_getInstanceMethod(object_getClass(viewController),sendSelector));
        ((BOOL(*)(id,SEL,id,id))send)(viewController,sendSelector,text,text);
        return;
    }
    IMP original=atomic_load_explicit(&timantirecall_replayOriginal,memory_order_acquire);
    if(original)((void(*)(id,SEL,id,id,id,id))original)(receiver,selector,gesture,record,viewController,tappedCellView);
}
BOOL timantirecall_installMessageReplay(void) {
    if(!NSThread.isMainThread)return NO;
    if(timantirecall_replayInstalled)return YES;
#ifdef TIMANTIRECALL_UI_TEST
    Class service=objc_getClass("NTAIOContentDoubleTapService");
#else
    Class service=objc_getClass("NTAIOContentDoubleTapService");
#endif
    SEL selector=sel_registerName("doubleTapGestureActionWithGesture:record:viewController:tappedCellView:");
    Method method=service?class_getClassMethod(service,selector):NULL;
    const char *args[]={"@",":","@","@","@","@"};
    if(!timantirecall_methodTypes(method,"v",6,args))return NO;
    atomic_store_explicit(&timantirecall_replayOriginal,method_getImplementation(method),memory_order_release);
    method_setImplementation(method,(IMP)timantirecall_replayDoubleTap);
    timantirecall_replayInstalled=YES;
    return YES;
}
