#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// Deliberately retain TIM's q/i/@ getter encodings for production ABI checks.
@interface OCMsgRecord : NSObject
@property(nonatomic) int64_t msgId, msgSeq, msgRandom, msgTime, peerUin, clientSeq, recallTime;
@property(nonatomic) NSUInteger timantirecall_recallSetterCalls;
@property(nonatomic) int chatType;
@property(nonatomic,copy) NSString *senderUid, *peerUid;
@end
@interface QQAccountsManager : NSObject
@property(nonatomic,copy) NSString *currentUid;
+ (instancetype)GetInstance;
@end
@interface OCInitSessionConfig : NSObject
@property(nonatomic,copy) NSString *selfUid;
@end
@interface TIMAntiRecallTestSession : NSObject
@property(nonatomic) NSUInteger timantirecall_initCalls, timantirecall_closeCalls;
@property(nonatomic,strong) NSArray *timantirecall_lastArguments;
- (void)init:(nullable id)config depends:(nullable id)depends dispatcherDepends:(nullable id)dispatcher listener:(nullable id)listener __attribute__((objc_method_family(none)));
@property(nonatomic) NSUInteger timantirecall_pushCalls;
@property(nonatomic,strong) NSArray *timantirecall_lastPush;
- (void)onMsfPush:(id)command msgBuffer:(id)buffer pushExtraInfo:(id)extra;
- (void)close:(nullable id)callback;
@end
@interface TIMAntiRecallTestBaseView : UIView
@property(nonatomic,strong,nullable) id timantirecall_model;
@property(nonatomic,weak,nullable) id timantirecall_lastBindArgument;
@property(nonatomic) BOOL timantirecall_bindResult;
@property(nonatomic) NSUInteger timantirecall_binds, timantirecall_unbinds, timantirecall_reuses;
@property(nonatomic) NSUInteger timantirecall_layouts, timantirecall_windowMoves;
- (BOOL)bindViewModel:(nullable id)model;
- (void)unbindViewModel;
- (void)prepareForReuse;
@end
@interface QQMessageModel : NSObject
@property(nonatomic) int64_t msgSeq,msgUid;
@property(nonatomic) int msgID;
@property(nonatomic,copy,nullable) NSString *peerUin,*groupCode;
@end
@interface QQAIOModel : NSObject
@property(nonatomic,strong,nullable) QQMessageModel *msgModel;
@end
@interface QQAIOMsgModel : QQAIOModel @end
@interface RecallNotiAIOModel : QQAIOModel @end
@interface NTRecordConverter : NSObject
+ (nullable QQMessageModel *)recordConvertMessageModel:(nullable OCMsgRecord *)record;
@end
@interface TIMAntiRecallTestOuterReuseCell : UITableViewCell
@property(nonatomic) NSUInteger timantirecall_reuses;
@end
@interface QQAIOCell : UITableViewCell
@property(nonatomic,strong,nullable) QQAIOModel *aioModel;
@property(nonatomic) NSUInteger timantirecall_sets,timantirecall_updates,timantirecall_reuses;
@property(nonatomic) NSUInteger timantirecall_layouts,timantirecall_windows;
@property(nonatomic,weak,nullable) QQAIOModel *timantirecall_lastModel;
- (void)updateCellView;
@end
@interface QQSettingsViewController : UIViewController
@property(nonatomic) NSUInteger timantirecall_appearCalls;
@property(nonatomic) BOOL timantirecall_lastAnimated;
@end
@interface QQChatSettingViewController : QQSettingsViewController
@property(nonatomic,copy) NSString *uin;
@end
@interface QQGroupSettingViewController : QQSettingsViewController
@property(nonatomic,copy) NSString *groupCode;
@end
NS_ASSUME_NONNULL_END
