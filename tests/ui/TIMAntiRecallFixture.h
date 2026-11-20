#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// Deliberately retain TIM's q/i/@ getter encodings for production ABI checks.
@class OCMsgElement;
@interface OCMsgRecord : NSObject
@property(nonatomic) int64_t msgId, msgSeq, msgRandom, msgTime, peerUin, clientSeq, recallTime;
@property(nonatomic) NSUInteger timantirecall_recallSetterCalls;
@property(nonatomic) int chatType, msgType;
@property(nonatomic) BOOL isOnlineMsg, isImportMsg;
@property(nonatomic,copy,nullable) NSArray<OCMsgElement *> *elements;
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
@interface OCTextElement : NSObject
@property(nonatomic,copy) NSString *content;
@property(nonatomic) int atType;
@property(nonatomic) int64_t atUid,atTinyId;
@property(nonatomic,copy,nullable) id atNtUid;
@property(nonatomic,copy,nullable) id subElementType;
@property(nonatomic,copy,nullable) id atChannelId;
@property(nonatomic,copy,nullable) id linkInfo;
@property(nonatomic,copy,nullable) id atRoleColor;
@property(nonatomic,copy,nullable) id atRoleName;
@property(nonatomic,copy,nullable) id needNotify;
@property(nonatomic,copy,nullable) id atRoleId;
@end
@interface OCWalletElement : NSObject
@property(nonatomic) int32_t msgType;
@property(nonatomic) uint64_t grabbedAmount;
@property(nonatomic,copy) NSString *billNo;
@end
@interface OCMsgElement : NSObject
@property(nonatomic) int32_t elementType;
@property(nonatomic,strong,nullable) OCWalletElement *walletElement;
@property(nonatomic,strong,nullable) OCTextElement *textElement;
@property(nonatomic,strong,nullable) id faceElement;
@property(nonatomic,strong,nullable) id marketFaceElement;
@property(nonatomic,strong,nullable) id replyElement;
@property(nonatomic,strong,nullable) id picElement;
@property(nonatomic,strong,nullable) id pttElement;
@property(nonatomic,strong,nullable) id videoElement;
@property(nonatomic,strong,nullable) id grayTipElement;
@property(nonatomic,strong,nullable) id arkElement;
@property(nonatomic,strong,nullable) id fileElement;
@property(nonatomic,strong,nullable) id liveGiftElement;
@property(nonatomic,strong,nullable) id markdownElement;
@property(nonatomic,strong,nullable) id structLongMsgElement;
@property(nonatomic,strong,nullable) id multiForwardMsgElement;
@property(nonatomic,strong,nullable) id giphyElement;
@property(nonatomic,strong,nullable) id inlineKeyboardElement;
@property(nonatomic,strong,nullable) id textGiftElement;
@property(nonatomic,strong,nullable) id calendarElement;
@property(nonatomic,strong,nullable) id yoloGameResultElement;
@property(nonatomic,strong,nullable) id avRecordElement;
@property(nonatomic,strong,nullable) id structMsgElement;
@property(nonatomic,strong,nullable) id faceBubbleElement;
@property(nonatomic,strong,nullable) id shareLocationElement;
@property(nonatomic,strong,nullable) id tofuRecordElement;
@property(nonatomic,strong,nullable) id taskTopMsgElement;
@property(nonatomic,strong,nullable) id recommendedMsgElement;
@property(nonatomic,strong,nullable) id actionBarElement;
@property(nonatomic,strong,nullable) id prologueMsgElement;
@end
@interface QQBaseChatViewController : UIViewController
@property(nonatomic) NSUInteger timantirecall_sendCalls;
@property(nonatomic,copy,nullable) NSString *timantirecall_lastText,*timantirecall_lastShowText;
- (BOOL)sendTextMsg:(NSString *)text showText:(NSString *)showText;
@end
@interface QQChatViewController : QQBaseChatViewController @end
@interface NTAIOContentDoubleTapService : NSObject
@property(class,nonatomic) NSUInteger timantirecall_originalCalls;
+ (void)doubleTapGestureActionWithGesture:(id)gesture record:(id)record viewController:(id)controller tappedCellView:(id)view;
@end
NS_ASSUME_NONNULL_END
