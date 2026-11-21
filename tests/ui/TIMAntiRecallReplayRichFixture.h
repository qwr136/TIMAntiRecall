#pragma once
#import "TIMAntiRecallFixture.h"

// Synthetic private classes, generated ONLY from locked QQ ivars/getter metadata.
// TIM 4.1.0.81; QQ UUID 3C237FA0-5985-3376-BF98-EF1698563247.
// I/i/Q/q/B retain exact widths; senderUid is NSNumber, not an integer.
@class OCReplyAbsFaceElement, OCReplyAbsPicElement, OCEmojiAD, OCEmojiMall, OCEmojiZPlan;
NS_ASSUME_NONNULL_BEGIN
@interface OCFaceElement : NSObject
@property(nonatomic) uint32_t faceIndex;
@property(nonatomic) int32_t faceType;
@property(nonatomic,strong,nullable) NSString *faceText;
@property(nonatomic,strong,nullable) NSString *packId;
@property(nonatomic,strong,nullable) NSString *stickerId;
@property(nonatomic,strong,nullable) NSNumber *sourceType;
@property(nonatomic,strong,nullable) NSNumber *stickerType;
@property(nonatomic,strong,nullable) NSString *resultId;
@property(nonatomic,strong,nullable) NSString *surpriseId;
@property(nonatomic,strong,nullable) NSNumber *randomType;
@property(nonatomic,strong,nullable) NSNumber *imageType;
@property(nonatomic,strong,nullable) NSNumber *pokeType;
@property(nonatomic,strong,nullable) NSString *spokeSummary;
@property(nonatomic,strong,nullable) NSNumber *doubleHit;
@property(nonatomic,strong,nullable) NSNumber *vaspokeId;
@property(nonatomic,strong,nullable) NSString *vaspokeName;
@property(nonatomic,strong,nullable) NSString *vaspokeMinver;
@property(nonatomic,strong,nullable) NSNumber *pokeStrength;
@property(nonatomic,strong,nullable) NSNumber *msgType;
@property(nonatomic,strong,nullable) NSNumber *faceBubbleCount;
@property(nonatomic,strong,nullable) NSString *oldVersionStr;
@property(nonatomic,strong,nullable) NSNumber *pokeFlag;
@property(nonatomic,strong,nullable) NSNumber *chainCount;
- (instancetype)init;
@end

@interface OCMarketFaceElement : NSObject
@property(nonatomic) uint32_t itemType;
@property(nonatomic) uint32_t faceInfo;
@property(nonatomic) uint32_t emojiPackageId;
@property(nonatomic) uint32_t subType;
@property(nonatomic) uint32_t mediaType;
@property(nonatomic) uint32_t imageWidth;
@property(nonatomic) uint32_t imageHeight;
@property(nonatomic,strong,nullable) NSString *faceName;
@property(nonatomic,strong,nullable) NSString *emojiId;
@property(nonatomic,strong,nullable) NSString *key;
@property(nonatomic,strong,nullable) NSData *param;
@property(nonatomic,strong,nullable) NSData *mobileParam;
@property(nonatomic,strong,nullable) NSNumber *sourceType;
@property(nonatomic,strong,nullable) NSNumber *startTime;
@property(nonatomic,strong,nullable) NSNumber *endTime;
@property(nonatomic,strong,nullable) NSNumber *emojiType;
@property(nonatomic,strong,nullable) NSNumber *hasIpProduct;
@property(nonatomic,strong,nullable) NSArray *voiceItemHeightArr;
@property(nonatomic,strong,nullable) NSString *sourceName;
@property(nonatomic,strong,nullable) NSString *sourceJumpUrl;
@property(nonatomic,strong,nullable) NSString *sourceTypeName;
@property(nonatomic,strong,nullable) NSString *backColor;
@property(nonatomic,strong,nullable) NSString *volumeColor;
@property(nonatomic,strong,nullable) NSString *staticFacePath;
@property(nonatomic,strong,nullable) NSString *dynamicFacePath;
@property(nonatomic,strong,nullable) NSArray *supportSize;
@property(nonatomic,strong,nullable) NSArray *apngSupportSize;
- (instancetype)init;
@end

@interface OCReplyElement : NSObject
@property(nonatomic) BOOL sourceMsgIsIncPic;
@property(nonatomic) BOOL sourceMsgExpired;
@property(nonatomic) uint32_t replyMsgRevokeType;
@property(nonatomic) int64_t replayMsgId;
@property(nonatomic,strong,nullable) NSNumber *replayMsgSeq;
@property(nonatomic,strong,nullable) NSNumber *replayMsgRootSeq;
@property(nonatomic,strong,nullable) NSNumber *replayMsgRootMsgId;
@property(nonatomic,strong,nullable) NSNumber *replayMsgRootCommentCnt;
@property(nonatomic,strong,nullable) NSNumber *sourceMsgIdInRecords;
@property(nonatomic,strong,nullable) NSString *sourceMsgText;
@property(nonatomic,strong,nullable) NSArray *sourceMsgTextElems;
@property(nonatomic,strong,nullable) NSNumber *senderUid;
@property(nonatomic,strong,nullable) NSString *senderUidStr;
@property(nonatomic,strong,nullable) NSNumber *replyMsgClientSeq;
@property(nonatomic,strong,nullable) NSNumber *replyMsgTime;
@property(nonatomic,strong,nullable) NSString *anonymousNickName;
@property(nonatomic,strong,nullable) NSNumber *originalMsgState;
- (instancetype)init;
@end

@interface OCReplyAbsElement : NSObject
@property(nonatomic) int32_t replyAbsElemType;
@property(nonatomic,strong,nullable) NSString *textElemContent;
@property(nonatomic,strong,nullable) OCReplyAbsFaceElement *faceElem;
@property(nonatomic,strong,nullable) OCReplyAbsPicElement *picElem;
- (instancetype)init;
@end

@interface OCReplyAbsFaceElement : NSObject
@property(nonatomic) uint32_t faceIndex;
@property(nonatomic) int32_t faceType;
@property(nonatomic,strong,nullable) NSString *faceText;
- (instancetype)init;
@end

@interface OCReplyAbsPicElement : NSObject
@property(nonatomic) uint32_t picWidth;
@property(nonatomic) uint32_t picHeight;
@property(nonatomic,strong,nullable) NSString *picText;
- (instancetype)init;
@end

@interface OCPicElement : NSObject
@property(nonatomic) BOOL original;
@property(nonatomic) int32_t picSubType;
@property(nonatomic) int32_t picWidth;
@property(nonatomic) int32_t picHeight;
@property(nonatomic) uint32_t thumbFileSize;
@property(nonatomic) uint32_t storeID;
@property(nonatomic,strong,nullable) NSString *fileName;
@property(nonatomic) uint64_t fileSize;
@property(nonatomic,strong,nullable) NSString *md5HexStr;
@property(nonatomic,strong,nullable) NSString *sourcePath;
@property(nonatomic,strong,nullable) NSDictionary *thumbPath;
@property(nonatomic,strong,nullable) NSNumber *transferStatus;
@property(nonatomic,strong,nullable) NSNumber *progress;
@property(nonatomic,strong,nullable) NSNumber *picType;
@property(nonatomic,strong,nullable) NSNumber *invalidState;
@property(nonatomic,strong,nullable) NSString *fileUuid;
@property(nonatomic,strong,nullable) NSString *fileSubId;
@property(nonatomic,strong,nullable) NSNumber *fileBizId;
@property(nonatomic,strong,nullable) NSString *downloadIndex;
@property(nonatomic,strong,nullable) NSString *summary;
@property(nonatomic,strong,nullable) NSNumber *emojiFrom;
@property(nonatomic,strong,nullable) NSString *emojiWebUrl;
@property(nonatomic,strong,nullable) OCEmojiAD *emojiAd;
@property(nonatomic,strong,nullable) OCEmojiMall *emojiMall;
@property(nonatomic,strong,nullable) OCEmojiZPlan *emojiZplan;
@property(nonatomic,strong,nullable) NSString *originImageMd5;
@property(nonatomic,strong,nullable) NSString *originImageUrl;
@property(nonatomic,strong,nullable) NSData *importRichMediaContext;
@property(nonatomic,strong,nullable) NSNumber *isFlashPic;
- (instancetype)init;
@end

// Independent value oracle: copies every declared field, recursively, without production code.
FOUNDATION_EXPORT id timantirecall_richFixtureValue(nullable id object);
FOUNDATION_EXPORT BOOL timantirecall_richFixtureABI(void);
NS_ASSUME_NONNULL_END
