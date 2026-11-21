#import "TIMAntiRecallFixture.h"

@implementation OCMsgRecord
- (void)setRecallTime:(int64_t)value { _recallTime=value;self.timantirecall_recallSetterCalls++; }
@end
@implementation QQMessageModel @end
@implementation QQAIOModel @end
@implementation QQAIOMsgModel @end
@implementation RecallNotiAIOModel @end
@implementation NTRecordConverter
+ (QQMessageModel *)recordConvertMessageModel:(OCMsgRecord *)record {
    if(!record)return nil;
    QQMessageModel *model=[QQMessageModel new];
    model.msgSeq=record.chatType==1?record.clientSeq:record.msgSeq;
    model.msgID=(int)record.msgId;model.msgUid=record.msgRandom;
    model.peerUin=@(record.peerUin).stringValue;
    model.groupCode=record.chatType==2?model.peerUin:nil;
    return model;
}
@end
@implementation QQAIOCell
- (void)setAioModel:(QQAIOModel *)model {
    self.timantirecall_sets++;self.timantirecall_lastModel=model;_aioModel=model;
}
- (void)updateCellView {self.timantirecall_updates++;}
- (void)prepareForReuse {[super prepareForReuse];self.timantirecall_reuses++;self.aioModel=nil;}
- (void)layoutSubviews {[super layoutSubviews];self.timantirecall_layouts++;}
- (void)didMoveToWindow {[super didMoveToWindow];self.timantirecall_windows++;}
@end
@implementation QQAccountsManager
+ (instancetype)GetInstance {
    static QQAccountsManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ manager=[self new]; manager.currentUid=@"self_uid"; });
    return manager;
}
@end
@implementation OCInitSessionConfig @end
@implementation TIMAntiRecallTestSession
- (void)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra {
    self.timantirecall_pushCalls++;
    self.timantirecall_lastPush=@[command?:NSNull.null,buffer?:NSNull.null,extra?:NSNull.null];
}
- (void)init:(id)config depends:(id)depends dispatcherDepends:(id)dispatcher listener:(id)listener {
    self.timantirecall_initCalls++;
    self.timantirecall_lastArguments=@[config?:NSNull.null, depends?:NSNull.null,
                                      dispatcher?:NSNull.null, listener?:NSNull.null];
}
- (void)close:(id)callback {
    self.timantirecall_closeCalls++;
    self.timantirecall_lastArguments=@[callback?:NSNull.null];
}
@end
@implementation TIMAntiRecallTestBaseView
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];
    if(self) self.timantirecall_bindResult=YES;
    return self;
}
- (BOOL)bindViewModel:(id)model {
    self.timantirecall_binds++;
    self.timantirecall_lastBindArgument=model;
    self.timantirecall_model=self.timantirecall_bindResult?model:nil;
    return self.timantirecall_bindResult;
}
- (void)unbindViewModel { self.timantirecall_unbinds++; self.timantirecall_model=nil; }
- (void)prepareForReuse { self.timantirecall_reuses++; self.timantirecall_model=nil; }
- (void)layoutSubviews { [super layoutSubviews]; self.timantirecall_layouts++; }
- (void)didMoveToWindow { [super didMoveToWindow]; self.timantirecall_windowMoves++; }
@end

@implementation QQSettingsViewController
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];self.timantirecall_appearCalls++;self.timantirecall_lastAnimated=animated;}
@end
@implementation QQChatSettingViewController
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];}
@end
@implementation QQGroupSettingViewController
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];}
@end
@implementation OCTextElement @end
@implementation OCMsgElement @end
@implementation QQBaseChatViewController
- (BOOL)sendTextMsg:(NSString *)text showText:(NSString *)showText {(void)text;(void)showText;return NO;}
@end
@implementation QQChatViewController
- (BOOL)sendTextMsg:(NSString *)text showText:(NSString *)showText {
    self.timantirecall_sendCalls++;self.timantirecall_lastText=[text copy];self.timantirecall_lastShowText=[showText copy];return YES;
}
@end
@implementation NTAIOContentDoubleTapService
static NSUInteger timantirecall_testOriginalDoubleTapCalls;
+ (NSUInteger)timantirecall_originalCalls{return timantirecall_testOriginalDoubleTapCalls;}
+ (void)setTimantirecall_originalCalls:(NSUInteger)value{timantirecall_testOriginalDoubleTapCalls=value;}
+ (void)doubleTapGestureActionWithGesture:(id)gesture record:(id)record viewController:(id)controller tappedCellView:(id)view {
    (void)gesture;(void)record;(void)controller;(void)view;timantirecall_testOriginalDoubleTapCalls++;
}
@end

@implementation OCContact @end
@implementation OCMsgRecord (TIMAntiRecallReplayContact)
- (OCContact *)contact {
    OCContact *contact=[OCContact new];contact.chatType=self.chatType;contact.peerUid=self.peerUid;contact.guildId=@"";return contact;
}
@end
@implementation QQMsgService
+ (instancetype)getInstance {static QQMsgService *service;static dispatch_once_t once;dispatch_once(&once,^{service=[QQMsgService new];});return service;}
- (void)sendMsgWithOCContact:(OCContact *)contact msgElems:(NSArray *)elements msgAttributeInfos:(NSDictionary *)attributes callBack:(void(^)(int32_t,NSString *))callback {
    self.timantirecall_sendCalls++;self.timantirecall_richSendCalls++;
    self.timantirecall_lastElements=elements;self.timantirecall_lastMsgAttributeInfos=attributes;
    self.timantirecall_lastContact=contact;self.timantirecall_lastText=nil;
    self.timantirecall_callbackWasNil=callback==nil;self.timantirecall_sendWasMainThread=NSThread.isMainThread;
    if(callback)callback(0,@"fixture success");
}
- (void)sendTextMsgByOCContact:(OCContact *)contact richText:(NSString *)text callBack:(void(^)(void))callback {
    self.timantirecall_sendCalls++;self.timantirecall_lastText=text;self.timantirecall_lastContact=contact;self.timantirecall_callbackWasNil=callback==nil;
}
@end
