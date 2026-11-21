#import "TIMAntiRecallReplayRichFixture.h"
#import <objc/runtime.h>
#include <string.h>

@implementation OCFaceElement
- (instancetype)init { return [super init]; }
@end
@implementation OCMarketFaceElement
- (instancetype)init { return [super init]; }
@end
@implementation OCReplyElement
- (instancetype)init { return [super init]; }
@end
@implementation OCReplyAbsElement
- (instancetype)init { return [super init]; }
@end
@implementation OCReplyAbsFaceElement
- (instancetype)init { return [super init]; }
@end
@implementation OCReplyAbsPicElement
- (instancetype)init { return [super init]; }
@end
@implementation OCPicElement
- (instancetype)init { return [super init]; }
@end

static NSDictionary<NSString *, NSArray<NSString *> *> *timantirecall_richFixtureKeys(void) {
    return @{
        @"OCFaceElement":@[@"faceIndex",@"faceType",@"faceText",@"packId",@"stickerId",@"sourceType",@"stickerType",@"resultId",@"surpriseId",@"randomType",@"imageType",@"pokeType",@"spokeSummary",@"doubleHit",@"vaspokeId",@"vaspokeName",@"vaspokeMinver",@"pokeStrength",@"msgType",@"faceBubbleCount",@"oldVersionStr",@"pokeFlag",@"chainCount"],
        @"OCMarketFaceElement":@[@"itemType",@"faceInfo",@"emojiPackageId",@"subType",@"mediaType",@"imageWidth",@"imageHeight",@"faceName",@"emojiId",@"key",@"param",@"mobileParam",@"sourceType",@"startTime",@"endTime",@"emojiType",@"hasIpProduct",@"voiceItemHeightArr",@"sourceName",@"sourceJumpUrl",@"sourceTypeName",@"backColor",@"volumeColor",@"staticFacePath",@"dynamicFacePath",@"supportSize",@"apngSupportSize"],
        @"OCReplyElement":@[@"sourceMsgIsIncPic",@"sourceMsgExpired",@"replyMsgRevokeType",@"replayMsgId",@"replayMsgSeq",@"replayMsgRootSeq",@"replayMsgRootMsgId",@"replayMsgRootCommentCnt",@"sourceMsgIdInRecords",@"sourceMsgText",@"sourceMsgTextElems",@"senderUid",@"senderUidStr",@"replyMsgClientSeq",@"replyMsgTime",@"anonymousNickName",@"originalMsgState"],
        @"OCReplyAbsElement":@[@"replyAbsElemType",@"textElemContent",@"faceElem",@"picElem"],
        @"OCReplyAbsFaceElement":@[@"faceIndex",@"faceType",@"faceText"],
        @"OCReplyAbsPicElement":@[@"picWidth",@"picHeight",@"picText"],
        @"OCPicElement":@[@"original",@"picSubType",@"picWidth",@"picHeight",@"thumbFileSize",@"storeID",@"fileName",@"fileSize",@"md5HexStr",@"sourcePath",@"thumbPath",@"transferStatus",@"progress",@"picType",@"invalidState",@"fileUuid",@"fileSubId",@"fileBizId",@"downloadIndex",@"summary",@"emojiFrom",@"emojiWebUrl",@"emojiAd",@"emojiMall",@"emojiZplan",@"originImageMd5",@"originImageUrl",@"importRichMediaContext",@"isFlashPic"],
        @"OCTextElement":@[@"atType",@"content",@"atUid",@"atTinyId",@"atNtUid",@"subElementType",@"atChannelId",@"linkInfo",@"atRoleId",@"atRoleColor",@"atRoleName",@"needNotify"],
        @"OCMsgElement":@[@"elementType",@"elementGroupId",@"elementId",@"extBufForUI",@"textElement",@"faceElement",@"marketFaceElement",@"replyElement",@"picElement",@"pttElement",@"videoElement",@"grayTipElement",@"arkElement",@"fileElement",@"liveGiftElement",@"markdownElement",@"structLongMsgElement",@"multiForwardMsgElement",@"giphyElement",@"walletElement",@"inlineKeyboardElement",@"textGiftElement",@"calendarElement",@"yoloGameResultElement",@"avRecordElement",@"structMsgElement",@"faceBubbleElement",@"shareLocationElement",@"tofuRecordElement",@"taskTopMsgElement",@"recommendedMsgElement",@"actionBarElement",@"prologueMsgElement"],
    };
}
id timantirecall_richFixtureValue(id object) {
    if(!object || object==NSNull.null)return NSNull.null;
    if([object isKindOfClass:NSString.class] || [object isKindOfClass:NSData.class] || [object isKindOfClass:NSNumber.class])return [object copy];
    if([object isKindOfClass:NSArray.class]) {
        NSMutableArray *values=[NSMutableArray array];
        for(id value in object)[values addObject:timantirecall_richFixtureValue(value)];
        return [values copy];
    }
    if([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *values=[NSMutableDictionary dictionary];
        for(id key in object)values[[key copy]]=timantirecall_richFixtureValue(object[key]);
        return [values copy];
    }
    NSString *name=NSStringFromClass([object class]);
    NSArray *keys=timantirecall_richFixtureKeys()[name];
    if(!keys)return @{@"class":name};
    NSMutableDictionary *values=[NSMutableDictionary dictionaryWithObject:name forKey:@"class"];
    for(NSString *key in keys)values[key]=timantirecall_richFixtureValue([object valueForKey:key]);
    return [values copy];
}
BOOL timantirecall_richFixtureABI(void) {
    { Class cls=[OCFaceElement class];
      const char *fields[][2]={
          {"faceIndex","I"},
          {"faceType","i"},
          {"faceText","@"},
          {"packId","@"},
          {"stickerId","@"},
          {"sourceType","@"},
          {"stickerType","@"},
          {"resultId","@"},
          {"surpriseId","@"},
          {"randomType","@"},
          {"imageType","@"},
          {"pokeType","@"},
          {"spokeSummary","@"},
          {"doubleHit","@"},
          {"vaspokeId","@"},
          {"vaspokeName","@"},
          {"vaspokeMinver","@"},
          {"pokeStrength","@"},
          {"msgType","@"},
          {"faceBubbleCount","@"},
          {"oldVersionStr","@"},
          {"pokeFlag","@"},
          {"chainCount","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    { Class cls=[OCMarketFaceElement class];
      const char *fields[][2]={
          {"itemType","I"},
          {"faceInfo","I"},
          {"emojiPackageId","I"},
          {"subType","I"},
          {"mediaType","I"},
          {"imageWidth","I"},
          {"imageHeight","I"},
          {"faceName","@"},
          {"emojiId","@"},
          {"key","@"},
          {"param","@"},
          {"mobileParam","@"},
          {"sourceType","@"},
          {"startTime","@"},
          {"endTime","@"},
          {"emojiType","@"},
          {"hasIpProduct","@"},
          {"voiceItemHeightArr","@"},
          {"sourceName","@"},
          {"sourceJumpUrl","@"},
          {"sourceTypeName","@"},
          {"backColor","@"},
          {"volumeColor","@"},
          {"staticFacePath","@"},
          {"dynamicFacePath","@"},
          {"supportSize","@"},
          {"apngSupportSize","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    { Class cls=[OCReplyElement class];
      const char *fields[][2]={
          {"sourceMsgIsIncPic","B"},
          {"sourceMsgExpired","B"},
          {"replyMsgRevokeType","I"},
          {"replayMsgId","q"},
          {"replayMsgSeq","@"},
          {"replayMsgRootSeq","@"},
          {"replayMsgRootMsgId","@"},
          {"replayMsgRootCommentCnt","@"},
          {"sourceMsgIdInRecords","@"},
          {"sourceMsgText","@"},
          {"sourceMsgTextElems","@"},
          {"senderUid","@"},
          {"senderUidStr","@"},
          {"replyMsgClientSeq","@"},
          {"replyMsgTime","@"},
          {"anonymousNickName","@"},
          {"originalMsgState","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    { Class cls=[OCReplyAbsElement class];
      const char *fields[][2]={
          {"replyAbsElemType","i"},
          {"textElemContent","@"},
          {"faceElem","@"},
          {"picElem","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    { Class cls=[OCReplyAbsFaceElement class];
      const char *fields[][2]={
          {"faceIndex","I"},
          {"faceType","i"},
          {"faceText","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    { Class cls=[OCReplyAbsPicElement class];
      const char *fields[][2]={
          {"picWidth","I"},
          {"picHeight","I"},
          {"picText","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    { Class cls=[OCPicElement class];
      const char *fields[][2]={
          {"original","B"},
          {"picSubType","i"},
          {"picWidth","i"},
          {"picHeight","i"},
          {"thumbFileSize","I"},
          {"storeID","I"},
          {"fileName","@"},
          {"fileSize","Q"},
          {"md5HexStr","@"},
          {"sourcePath","@"},
          {"thumbPath","@"},
          {"transferStatus","@"},
          {"progress","@"},
          {"picType","@"},
          {"invalidState","@"},
          {"fileUuid","@"},
          {"fileSubId","@"},
          {"fileBizId","@"},
          {"downloadIndex","@"},
          {"summary","@"},
          {"emojiFrom","@"},
          {"emojiWebUrl","@"},
          {"emojiAd","@"},
          {"emojiMall","@"},
          {"emojiZplan","@"},
          {"originImageMd5","@"},
          {"originImageUrl","@"},
          {"importRichMediaContext","@"},
          {"isFlashPic","@"},
      };
      for(NSUInteger index=0;index<sizeof(fields)/sizeof(fields[0]);index++) {
          Method method=class_getInstanceMethod(cls,sel_registerName(fields[index][0]));
          char type[8]={0};if(!method)return NO;method_getReturnType(method,type,sizeof(type));
          if(strcmp(type,fields[index][1]))return NO;
      }
      if(strcmp(method_getTypeEncoding(class_getInstanceMethod(cls,@selector(init))),"@16@0:8"))return NO;
    }
    Method send=class_getInstanceMethod(QQMsgService.class,@selector(sendMsgWithOCContact:msgElems:msgAttributeInfos:callBack:));
    return send && !strcmp(method_getTypeEncoding(send),"v48@0:8@16@24@32@?40");
}
