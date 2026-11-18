#import "TIMAntiRecallPreferencesUI.h"
#import "TIMAntiRecallSettings.h"
#import "TIMAntiRecallMarks.h"
#include <stdatomic.h>
#include <stdlib.h>

@interface TIMAntiRecallPreferencesEntryTarget : NSObject
@property(nonatomic,weak) UIViewController *timantirecall_controller;
@property(nonatomic) unsigned timantirecall_kind;
@property(nonatomic,strong) UIBarButtonItem *timantirecall_button;
- (void)timantirecall_open;
@end
static char timantirecall_preferencesEntryKey;
static _Atomic(IMP) timantirecall_settingsOriginal[3];
static BOOL timantirecall_settingsInstalled[3];
@implementation TIMAntiRecallPreferencesEntryTarget
- (void)timantirecall_open {
    UIViewController *controller=self.timantirecall_controller;
    NSString *owner=timantirecall_currentAccount();
    if(!controller || controller.presentedViewController || !owner.length)return;
    NSDictionary *chat=nil;
    if(self.timantirecall_kind) {
        SEL getter=sel_registerName(self.timantirecall_kind==1?"uin":"groupCode");
        const char *args[]={"@",":"};
        Method method=class_getInstanceMethod(object_getClass(controller),getter);
        if(timantirecall_methodTypes(method,"@",2,args)) {
            id alias=((id(*)(id,SEL))[controller methodForSelector:getter])(controller,getter);
            chat=[timantirecall_settings() timantirecall_chatForAlias:alias kind:self.timantirecall_kind owner:owner];
        }
        if(!chat) {
            UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"尚未确认此聊天身份"
                message:@"请先回到聊天查看一条普通消息，再打开此入口。不会根据昵称或列表位置猜测聊天。也可在TIM设置的防撤回面板管理已识别聊天。"
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
            [controller presentViewController:alert animated:YES completion:nil];return;
        }
    }
    TIMAntiRecallPreferencesController *preferences=[[TIMAntiRecallPreferencesController alloc] initWithOwner:owner chat:chat];
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:preferences];
    navigation.modalPresentationStyle=UIModalPresentationPageSheet;
    [controller presentViewController:navigation animated:NO completion:nil];
}
@end
static void timantirecall_attachPreferences(UIViewController *controller,unsigned kind) {
    if(!NSThread.isMainThread)return;
    TIMAntiRecallPreferencesEntryTarget *target=objc_getAssociatedObject(controller,&timantirecall_preferencesEntryKey);
    if(!target) {
        target=[TIMAntiRecallPreferencesEntryTarget new];target.timantirecall_controller=controller;
        target.timantirecall_button=[[UIBarButtonItem alloc] initWithTitle:@"防撤回" style:UIBarButtonItemStylePlain target:target action:@selector(timantirecall_open)];
        target.timantirecall_button.accessibilityIdentifier=@"TIMAntiRecall.preferencesEntry";
        objc_setAssociatedObject(controller,&timantirecall_preferencesEntryKey,target,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    target.timantirecall_kind=kind;
    NSMutableArray *items=[controller.navigationItem.rightBarButtonItems mutableCopy]?:[NSMutableArray array];
    if(![items containsObject:target.timantirecall_button]) {
        [items addObject:target.timantirecall_button];controller.navigationItem.rightBarButtonItems=items;
    }
}
static void timantirecall_settingsAppear(id receiver,SEL selector,BOOL animated,unsigned index) {
    IMP original=atomic_load_explicit(&timantirecall_settingsOriginal[index],memory_order_acquire);
    if(original)((void(*)(id,SEL,BOOL))original)(receiver,selector,animated);
    timantirecall_attachPreferences(receiver,index);
}
static void timantirecall_settingsAppear0(id receiver,SEL selector,BOOL animated){timantirecall_settingsAppear(receiver,selector,animated,0);}
static void timantirecall_settingsAppear1(id receiver,SEL selector,BOOL animated){timantirecall_settingsAppear(receiver,selector,animated,1);}
static void timantirecall_settingsAppear2(id receiver,SEL selector,BOOL animated){timantirecall_settingsAppear(receiver,selector,animated,2);}
BOOL timantirecall_installPreferences(void) {
    if(!NSThread.isMainThread)return NO;
    const char *names[]={"QQSettingsViewController","QQChatSettingViewController","QQGroupSettingViewController"};
    IMP replacements[]={(IMP)timantirecall_settingsAppear0,(IMP)timantirecall_settingsAppear1,(IMP)timantirecall_settingsAppear2};
    SEL selector=@selector(viewDidAppear:);const char *args[]={"@",":","B"};BOOL all=YES;
    for(unsigned index=0;index<3;index++) {
        if(timantirecall_settingsInstalled[index])continue;
        Class cls=objc_getClass(names[index]);
        if(!cls||![cls isSubclassOfClass:UIViewController.class]){all=NO;continue;}
        Method own=NULL;unsigned count=0;Method *methods=class_copyMethodList(cls,&count);
        for(unsigned m=0;m<count;m++)if(method_getName(methods[m])==selector){own=methods[m];break;}
        free(methods);
        if(!timantirecall_methodTypes(own,"v",3,args)){all=NO;continue;}
        IMP original=method_getImplementation(own);if(!original){all=NO;continue;}
        atomic_store_explicit(&timantirecall_settingsOriginal[index],original,memory_order_release);
        method_setImplementation(own,replacements[index]);timantirecall_settingsInstalled[index]=YES;
    }
    return all;
}
