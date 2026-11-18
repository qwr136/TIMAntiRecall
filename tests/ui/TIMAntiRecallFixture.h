#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// Deliberately retain TIM's q/i/@ getter encodings for production ABI checks.
@interface OCMsgRecord : NSObject
@property(nonatomic) int64_t msgId, msgSeq, msgRandom, msgTime, peerUin;
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
NS_ASSUME_NONNULL_END
