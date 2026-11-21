#pragma once
#import "TIMAntiRecallReplay.h"
#import "TIMAntiRecallReplayPayload.h"
#import "TIMAntiRecallReplayRichFixture.h"

// Real UIKit row/chat/recognizer path; all private TIM classes are synthetic.
// The production snapshot is deliberately opaque to these regression cases.
static BOOL timantirecall_richImmutable(id value) {
    if([value isKindOfClass:NSMutableDictionary.class] || [value isKindOfClass:NSMutableArray.class] ||
       [value isKindOfClass:NSMutableString.class] || [value isKindOfClass:NSMutableData.class])return NO;
    if([value isKindOfClass:NSDictionary.class]) {
        for(id key in value)if(!timantirecall_richImmutable(key)||!timantirecall_richImmutable(value[key]))return NO;
        return YES;
    }
    if([value isKindOfClass:NSArray.class]) { for(id child in value)if(!timantirecall_richImmutable(child))return NO;return YES; }
    return value==NSNull.null || [value isKindOfClass:NSString.class] || [value isKindOfClass:NSData.class] || [value isKindOfClass:NSNumber.class];
}
static OCMsgElement *timantirecall_richElement(id payload, NSString *slot, int32_t type) {
    OCMsgElement *element=[OCMsgElement new];element.elementType=type;element.elementId=456789;
    element.elementGroupId=31;element.extBufForUI=[@"old UI extension" dataUsingEncoding:NSUTF8StringEncoding];
    [element setValue:payload forKey:slot];return element;
}
static OCTextElement *timantirecall_richText(NSString *body) {
    OCTextElement *text=[OCTextElement new];text.content=body;text.atNtUid=@"";
    text.subElementType=@0;text.atChannelId=@0;text.atRoleId=@0;text.atRoleColor=@0;return text;
}
static OCFaceElement *timantirecall_richFace(void) {
    OCFaceElement *face=[OCFaceElement new];face.faceIndex=14;face.faceType=1;
    face.faceText=[@"[微笑]" mutableCopy];face.packId=@"fixture-pack";face.stickerId=@"fixture-sticker";
    face.sourceType=@2;face.stickerType=@1;face.resultId=@"";face.surpriseId=@"surprise";
    face.randomType=@0;face.imageType=@1;face.pokeType=@0;face.spokeSummary=@"summary";
    face.doubleHit=@0;face.vaspokeId=@0;face.vaspokeName=@"";face.vaspokeMinver=@"1";
    face.pokeStrength=@0;face.msgType=@3;face.faceBubbleCount=@0;face.oldVersionStr=@"fallback";
    face.pokeFlag=@0;face.chainCount=@0;return face;
}
static OCMarketFaceElement *timantirecall_richMarketFace(void) {
    OCMarketFaceElement *face=[OCMarketFaceElement new];face.itemType=6;face.faceInfo=2;
    face.emojiPackageId=UINT32_C(0xf1234567);face.subType=1;face.mediaType=2;face.imageWidth=240;face.imageHeight=180;
    face.faceName=[@"市场表情" mutableCopy];face.emojiId=@"fixture-emoji";face.key=@"fixture-key";
    face.param=[[@"binary-param" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    face.mobileParam=[[@"mobile-param" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    face.sourceType=@1;face.startTime=@100;face.endTime=@200;face.emojiType=@3;face.hasIpProduct=@NO;
    face.voiceItemHeightArr=[NSMutableArray arrayWithObjects:@16,@32,nil];face.sourceName=@"fixture-source";
    face.sourceJumpUrl=@"https://example.invalid/sticker";face.sourceTypeName=@"market";
    face.backColor=@"ffffff";face.volumeColor=@"000000";face.staticFacePath=@"fixture-static";
    face.dynamicFacePath=@"fixture-dynamic";face.supportSize=[NSMutableArray arrayWithObjects:@64,@128,nil];
    face.apngSupportSize=[NSMutableArray arrayWithObject:@256];return face;
}
static OCReplyElement *timantirecall_richReply(void) {
    OCReplyAbsElement *text=[OCReplyAbsElement new];text.replyAbsElemType=1;text.textElemContent=[@"引用原文，不是本次回复正文" mutableCopy];
    OCReplyAbsElement *face=[OCReplyAbsElement new];face.replyAbsElemType=3;face.faceElem=[OCReplyAbsFaceElement new];
    face.faceElem.faceIndex=66;face.faceElem.faceType=1;face.faceElem.faceText=[@"[引用表情]" mutableCopy];
    OCReplyAbsElement *pic=[OCReplyAbsElement new];pic.replyAbsElemType=2;pic.picElem=[OCReplyAbsPicElement new];
    pic.picElem.picWidth=640;pic.picElem.picHeight=480;pic.picElem.picText=[@"[引用图片]" mutableCopy];
    OCReplyElement *reply=[OCReplyElement new];reply.replayMsgId=INT64_C(4294967331);reply.replayMsgSeq=@9001;
    reply.replayMsgRootSeq=@8001;reply.replayMsgRootMsgId=@8002;reply.replayMsgRootCommentCnt=@7;
    reply.sourceMsgIdInRecords=@13;reply.sourceMsgText=[@"引用原文，不是本次回复正文" mutableCopy];
    reply.sourceMsgTextElems=[NSMutableArray arrayWithObjects:text,face,pic,nil];reply.senderUid=@7654321;
    reply.senderUidStr=@"quoted_author";reply.replyMsgClientSeq=@201;reply.replyMsgTime=@1700000001;
    reply.anonymousNickName=@"quoted_nick";reply.originalMsgState=@0;reply.sourceMsgIsIncPic=YES;
    reply.sourceMsgExpired=NO;reply.replyMsgRevokeType=0;return reply;
}
static BOOL timantirecall_richDoubleTap(TIMAntiRecallTestBaseView *row, CGPoint point, NSTimeInterval time) {
    return timantirecall_testReplayCapture(row,point,time) && timantirecall_testReplayCapture(row,point,time+0.1) && timantirecall_testReplayComplete(row,point);
}
static void timantirecall_richCheckClone(OCMsgRecord *record, NSDictionary *snapshot, NSArray *clones, NSArray<NSString *> *slots) {
    timantirecall_check(snapshot && timantirecall_richImmutable(snapshot),@"rich snapshot contains only deeply immutable values, never source objects");
    timantirecall_check(clones.count==record.elements.count && clones.count==slots.count,@"rich rebuild preserves full message element count and order");
    if(clones.count!=record.elements.count || clones.count!=slots.count)return;
    for(NSUInteger index=0;index<clones.count;index++) {
        OCMsgElement *original=record.elements[index], *fresh=clones[index];NSString *slot=slots[index];
        id originalPayload=[original valueForKey:slot], freshPayload=[fresh valueForKey:slot];
        timantirecall_check([fresh isKindOfClass:OCMsgElement.class] && fresh!=original && fresh.elementId==0 && fresh.elementType==original.elementType,@"rich rebuild allocates native OCMsgElement with reset element id");
        timantirecall_check(freshPayload!=originalPayload && [freshPayload class]==[originalPayload class] && [timantirecall_richFixtureValue(freshPayload) isEqual:timantirecall_richFixtureValue(originalPayload)],@"rich rebuild deep-copies each payload and all verified metadata fields");
    }
}
static void timantirecall_testRichReplay(UIView *root) {
    __block UIViewController *chat;__block UIScrollView *scroll;__block UITableViewCell *host;
    __block TIMAntiRecallTestBaseView *row;__block UITextView *draft;__block OCMsgRecord *record;
    __block OCFaceElement *face;__block OCMarketFaceElement *market;__block OCReplyElement *reply;__block OCTextElement *body;
    __block NSArray *originalValues;__block NSDictionary *oldAttrs;__block CGPoint outside=CGPointMake(180,30);
    timantirecall_step(^{
        timantirecall_check(NSThread.isMainThread && timantirecall_richFixtureABI(),@"rich fixture getters and init retain locked QQ ABI, native sender is v48 with block callback");
        [QQAccountsManager GetInstance].currentUid=@"self_uid";
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:nil];
        timantirecall_check(timantirecall_installMessageReplay(),@"rich replay lifecycle installed");
        QQMsgService *service=[QQMsgService getInstance];service.timantirecall_sendCalls=0;service.timantirecall_richSendCalls=0;
        chat=[TIMAntiRecallSwiftFixture timantirecall_replayControllerWithPeer:@"peer_a" type:1];
        chat.view.frame=root.bounds;[root addSubview:chat.view];
        scroll=[[UIScrollView alloc] initWithFrame:chat.view.bounds];scroll.contentSize=CGSizeMake(root.bounds.size.width,root.bounds.size.height*2);[chat.view addSubview:scroll];
        host=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];host.frame=CGRectMake(0,80,root.bounds.size.width,64);[scroll addSubview:host];[host layoutIfNeeded];
        row=[TIMAntiRecallSwiftFixture timantirecall_replayRowWithFrame:host.contentView.bounds];[host.contentView addSubview:row];
        draft=[[UITextView alloc] initWithFrame:CGRectMake(0,root.bounds.size.height-90,200,40)];draft.text=@"富消息复读不能改草稿";[chat.view addSubview:draft];
        face=timantirecall_richFace();record=timantirecall_record(1,1251,@"peer_a",0);
        record.elements=@[timantirecall_richElement(face,@"faceElement",3)];
        oldAttrs=@{@"old-delivery-id":@12345};record.msgAttrs=oldAttrs;
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        QQMsgService *service=[QQMsgService getInstance];originalValues=timantirecall_richFixtureValue(record.elements);
        NSDictionary *snapshot=timantirecall_richReplaySnapshot(record);NSArray *clones=timantirecall_richReplayElements(snapshot);
        timantirecall_richCheckClone(record,snapshot,clones,@[@"faceElement"]);
        NSArray *again=timantirecall_richReplayElements(snapshot);
        timantirecall_check(clones.firstObject!=again.firstObject && [clones.firstObject faceElement]!=[again.firstObject faceElement],@"building one face snapshot twice never reuses elements or payload objects");
        [(NSMutableString *)face.faceText appendString:@" changed after snapshot"];
        OCFaceElement *frozen=[timantirecall_richReplayElements(snapshot).firstObject faceElement];
        timantirecall_check([frozen.faceText isEqual:@"[微笑]"],@"face snapshot detaches mutable source strings before rebuilding");
        [(NSMutableString *)face.faceText setString:@"[微笑]"];
        timantirecall_check(timantirecall_richDoubleTap(row,outside,30),@"single face replays through actual NT row double-tap decisions");
        timantirecall_check(service.timantirecall_richSendCalls==1 && service.timantirecall_sendCalls==1 && service.timantirecall_lastElements.count==1 && service.timantirecall_sendWasMainThread && !service.timantirecall_callbackWasNil,@"single face calls native rich sender once on main thread with completion callback");
        timantirecall_check(!timantirecall_testReplayComplete(row,outside) && service.timantirecall_richSendCalls==1,@"rich recognized double tap cannot submit twice");
        timantirecall_richCheckClone(record,snapshot,service.timantirecall_lastElements,@[@"faceElement"]);
        OCFaceElement *sent=[service.timantirecall_lastElements.firstObject faceElement];sent.faceIndex=999;sent.faceText=@"sender-mutated";
        [service.timantirecall_lastElements.firstObject setElementId:999];
        timantirecall_check([originalValues isEqual:timantirecall_richFixtureValue(record.elements)] && record.msgAttrs==oldAttrs && service.timantirecall_lastMsgAttributeInfos.count==0,@"native face send cannot mutate source record or copy old message attributes");
        market=timantirecall_richMarketFace();record.elements=@[timantirecall_richElement(market,@"marketFaceElement",11)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        QQMsgService *service=[QQMsgService getInstance];originalValues=timantirecall_richFixtureValue(record.elements);
        NSDictionary *snapshot=timantirecall_richReplaySnapshot(record);NSArray *clones=timantirecall_richReplayElements(snapshot);
        timantirecall_richCheckClone(record,snapshot,clones,@[@"marketFaceElement"]);
        [(NSMutableData *)market.param appendData:[@"changed" dataUsingEncoding:NSUTF8StringEncoding]];
        [(NSMutableArray *)market.supportSize addObject:@512];
        OCMarketFaceElement *frozen=[timantirecall_richReplayElements(snapshot).firstObject marketFaceElement];
        timantirecall_check([frozen.param isEqual:[@"binary-param" dataUsingEncoding:NSUTF8StringEncoding]] && [frozen.supportSize isEqual:@[@64,@128]] && frozen.emojiPackageId==UINT32_C(0xf1234567),@"market snapshot detaches binary data and nested arrays and preserves unsigned metadata");
        market.param=[[@"binary-param" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[(NSMutableArray *)market.supportSize removeLastObject];
        timantirecall_check(timantirecall_richDoubleTap(row,outside,31),@"market face replays through NT row double tap");
        timantirecall_check(service.timantirecall_richSendCalls==2 && service.timantirecall_lastElements.count==1 && service.timantirecall_sendWasMainThread && !service.timantirecall_callbackWasNil,@"market face uses native rich sender with one cloned element");
        timantirecall_richCheckClone(record,snapshot,service.timantirecall_lastElements,@[@"marketFaceElement"]);
        OCMarketFaceElement *sent=[service.timantirecall_lastElements.firstObject marketFaceElement];sent.param=NSData.data;sent.supportSize=@[];
        timantirecall_check([originalValues isEqual:timantirecall_richFixtureValue(record.elements)],@"market send and payload changes leave original data and arrays intact");
        reply=timantirecall_richReply();body=timantirecall_richText(@"这才是整条回复正文");face=timantirecall_richFace();
        record.elements=@[timantirecall_richElement(reply,@"replyElement",7),timantirecall_richElement(body,@"textElement",1),timantirecall_richElement(face,@"faceElement",3)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        QQMsgService *service=[QQMsgService getInstance];originalValues=timantirecall_richFixtureValue(record.elements);
        NSDictionary *snapshot=timantirecall_richReplaySnapshot(record);NSArray *clones=timantirecall_richReplayElements(snapshot);
        timantirecall_richCheckClone(record,snapshot,clones,@[@"replyElement",@"textElement",@"faceElement"]);
        OCReplyElement *copy=[clones.firstObject replyElement];
        timantirecall_check(copy.sourceMsgTextElems!=reply.sourceMsgTextElems && copy.sourceMsgTextElems.count==3 && [copy.senderUid isKindOfClass:NSNumber.class] && [copy.senderUid isEqual:reply.senderUid],@"reply clone preserves object senderUid and independent full quote preview");
        if(copy.sourceMsgTextElems.count==3) {
            for(NSUInteger i=0;i<3;i++)timantirecall_check(copy.sourceMsgTextElems[i]!=reply.sourceMsgTextElems[i],@"every quote preview descriptor is a new native object");
            OCReplyAbsElement *sourceFace=reply.sourceMsgTextElems[1], *sourcePic=reply.sourceMsgTextElems[2];
            OCReplyAbsElement *cloneFace=copy.sourceMsgTextElems[1], *clonePic=copy.sourceMsgTextElems[2];
            timantirecall_check(cloneFace.faceElem!=sourceFace.faceElem && clonePic.picElem!=sourcePic.picElem,@"nested quote face and picture payloads never alias source");
            cloneFace.faceElem.faceIndex=999;clonePic.picElem.picText=@"mutated clone preview";
        }
        [(NSMutableString *)reply.sourceMsgText appendString:@" changed source"];
        OCReplyElement *frozen=[timantirecall_richReplayElements(snapshot).firstObject replyElement];
        timantirecall_check([frozen.sourceMsgText isEqual:@"引用原文，不是本次回复正文"],@"reply snapshot freezes original quote text");
        [(NSMutableString *)reply.sourceMsgText setString:@"引用原文，不是本次回复正文"];
        timantirecall_check([originalValues isEqual:timantirecall_richFixtureValue(record.elements)],@"building and mutating nested reply clones leaves every original field equal");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,32),@"reply plus text plus face replays as one whole quoted reply");
        timantirecall_check(service.timantirecall_richSendCalls==3 && service.timantirecall_sendCalls==3 && service.timantirecall_lastElements.count==3 && service.timantirecall_lastText==nil,@"quoted reply performs one rich submission, never separately sends quoted original text");
        timantirecall_richCheckClone(record,snapshot,service.timantirecall_lastElements,@[@"replyElement",@"textElement",@"faceElement"]);
        if(service.timantirecall_lastElements.count==3) {
            OCMsgElement *sentBody=service.timantirecall_lastElements[1];
            timantirecall_check([sentBody.textElement.content isEqual:@"这才是整条回复正文"] && ![sentBody.textElement.content isEqual:reply.sourceMsgText],@"reply body is not replaced by the quoted preview text");
            sentBody.textElement.content=@"sender mutated reply body";
            OCReplyElement *sentReply=[service.timantirecall_lastElements.firstObject replyElement];sentReply.replayMsgId=1;sentReply.senderUid=@1;
        }
        timantirecall_check([originalValues isEqual:timantirecall_richFixtureValue(record.elements)] && [draft.text isEqual:@"富消息复读不能改草稿"] && service.timantirecall_lastMsgAttributeInfos.count==0 && [service.timantirecall_lastContact.peerUid isEqual:@"peer_a"],@"whole reply preserves record, draft and current contact without old msgAttrs");
    });
    timantirecall_step(^{
        QQMsgService *service=[QQMsgService getInstance];NSUInteger sent=service.timantirecall_sendCalls;
        timantirecall_check(timantirecall_testReplayCapture(row,outside,33),@"rich body-change negative control arms first tap");
        body.content=@"changed between taps";timantirecall_testReplayCapture(row,outside,33.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside),@"reply body mutation between taps invalidates rich replay");body.content=@"这才是整条回复正文";
        timantirecall_check(timantirecall_testReplayCapture(row,outside,34),@"rich quote-target negative control arms first tap");
        int64_t target=reply.replayMsgId;reply.replayMsgId++;
        timantirecall_testReplayCapture(row,outside,34.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside),@"quote target mutation between taps invalidates rich replay");reply.replayMsgId=target;
        timantirecall_check(timantirecall_testReplayCapture(row,outside,35),@"rich preview-change negative control arms first tap");
        OCReplyAbsElement *preview=reply.sourceMsgTextElems[1];preview.faceElem.faceIndex++;
        timantirecall_testReplayCapture(row,outside,35.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside),@"nested quote preview change between taps invalidates rich replay");preview.faceElem.faceIndex--;
        timantirecall_check(timantirecall_testReplayCapture(row,outside,36),@"rich chat-change negative control arms first tap");
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"other_chat" controller:chat type:1];
        timantirecall_testReplayCapture(row,outside,36.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside),@"rich replay refuses a different current chat");
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"peer_a" controller:chat type:1];
        timantirecall_check(timantirecall_testReplayCapture(row,outside,37),@"rich account-change negative control arms first tap");
        [QQAccountsManager GetInstance].currentUid=@"other_account";timantirecall_testReplayCapture(row,outside,37.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside),@"rich replay refuses an account change");
        [QQAccountsManager GetInstance].currentUid=@"self_uid";timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,38),@"rich scroll negative control arms first tap");
        scroll.contentOffset=CGPointMake(0,1);scroll.contentOffset=CGPointZero;timantirecall_testReplayCapture(row,outside,38.1);
        timantirecall_check(!timantirecall_testReplayComplete(row,outside),@"rich scroll change invalidates pending replay even when offset is restored");
        timantirecall_testReplayCapture(row,outside,39);[row prepareForReuse];
        timantirecall_check(!timantirecall_testReplayCapture(row,outside,39.1) && !timantirecall_testReplayComplete(row,outside),@"rich reused row cannot submit captured old record");
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_testReplayCapture(row,outside,40),@"rich disable negative control arms first tap");
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@NO} error:nil];
        timantirecall_check(!timantirecall_testReplayCapture(row,outside,40.1) && !timantirecall_testReplayComplete(row,outside),@"turning replay off prevents an already pending rich send");
        timantirecall_check(service.timantirecall_sendCalls==sent && [draft.text isEqual:@"富消息复读不能改草稿"],@"all rich context invalidation controls leave send count and draft unchanged");
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@YES} error:nil];timantirecall_updateReplayRow(row,@"self_uid");
    });
    timantirecall_step(^{
        QQMsgService *service=[QQMsgService getInstance];NSUInteger sent=service.timantirecall_sendCalls;
        OCMsgElement *unsupported=[OCMsgElement new];unsupported.elementType=999;
        OCMsgElement *wallet=[OCMsgElement new];wallet.elementType=9;wallet.walletElement=[OCWalletElement new];
        OCMsgElement *multi=timantirecall_richElement(face,@"faceElement",3);multi.textElement=timantirecall_richText(@"ambiguous dual payload");
        OCMsgElement *file=[OCMsgElement new];file.elementType=4;file.fileElement=[NSObject new];
        OCMsgElement *wrongType=timantirecall_richElement(face,@"faceElement",999);
        OCMsgElement *wrongClass=timantirecall_richElement([NSObject new],@"faceElement",3);
        NSArray *valid=record.elements;
        for(OCMsgElement *bad in @[unsupported,wallet,multi,file,wrongType,wrongClass]) {
            record.elements=@[bad];[row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
            timantirecall_check(timantirecall_richReplaySnapshot(record)==nil && !timantirecall_testReplayCapture(row,outside,41) && !timantirecall_testReplayComplete(row,outside),@"unknown, wallet, multi-payload, file and mismatched payloads fail closed without send");
        }
        OCTextElement *mention=timantirecall_richText(@"@someone");mention.atType=1;mention.atNtUid=@"someone";
        record.elements=@[timantirecall_richElement(mention,@"textElement",1)];
        timantirecall_check(timantirecall_richReplaySnapshot(record)==nil,@"rich fallback cannot bypass single-text mention rejection");
        record.elements=@[valid.firstObject];
        timantirecall_check(timantirecall_richReplaySnapshot(record)==nil,@"a quote descriptor alone cannot send only the quoted original");
        record.elements=valid;[row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(service.timantirecall_sendCalls==sent && [originalValues isEqual:timantirecall_richFixtureValue(record.elements)] && record.msgAttrs==oldAttrs,@"all unsupported rich cases leave sender and original full reply untouched");
        // Explicit group and own-message direction coverage; type 5 uses the
        // same verified face payload family, not a text downgrade.
        record.chatType=2;record.peerUin=7001;record.peerUid=@"7001";record.senderUid=@"self_uid";
        [TIMAntiRecallSwiftFixture timantirecall_setReplayPeer:@"7001" controller:chat type:2];
        NSDictionary *views=[TIMAntiRecallRecordBridge timantirecall_replayViewsForRow:row];
        UIView *bubble=views[@"content"],*avatar=views[@"avatar"];
        bubble.frame=CGRectMake(host.contentView.bounds.size.width-156,8,100,44);
        avatar.frame=CGRectMake(host.contentView.bounds.size.width-44,8,36,36);
        outside=CGPointMake(12,30);record.elements=@[timantirecall_richElement(face,@"faceElement",5)];
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,42)&&service.timantirecall_sendCalls==sent+1,@"own group native face type 5 replays from left whitespace");
        record.elements=valid;
        [row bindViewModel:[TIMAntiRecallSwiftFixture timantirecall_ntChat:record]];timantirecall_updateReplayRow(row,@"self_uid");
        timantirecall_check(timantirecall_richDoubleTap(row,outside,43)&&service.timantirecall_sendCalls==sent+2&&service.timantirecall_lastContact.chatType==2&&[service.timantirecall_lastContact.peerUid isEqual:@"7001"],@"own group quote replays whole reply through current group contact");
        [timantirecall_settings() timantirecall_updateOptions:@{@"messageReplay":@NO} error:nil];timantirecall_clearReplayRow(row);
        [chat.view removeFromSuperview];chat=nil;scroll=nil;host=nil;row=nil;draft=nil;record=nil;reply=nil;body=nil;face=nil;market=nil;
        [timantirecall_coverage addObjectsFromArray:@[@"rich-message-replay",@"rich-message-replay-quote",@"rich-message-replay-deep-copy",@"rich-message-replay-guards"]];
    });
}
