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
@implementation TIMAntiRecallTestOuterReuseCell
- (void)prepareForReuse {[super prepareForReuse];self.timantirecall_reuses++;}
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
